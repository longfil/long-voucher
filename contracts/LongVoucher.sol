// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "./ERC3525.sol";
import "./Errors.sol";
import "./ILongVoucher.sol";
import "./ISlotManager.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";

contract LongVoucher is ERC3525, Ownable2Step, ILongVoucher
{
    using Address for address;
    //// constants

    //// state

    struct SlotData {
        uint256 slot;
        uint256[] slotTokens;
        address slotManager;
    }

    // slot => tokenId => index
    mapping(uint256 => mapping(uint256 => uint256)) private _slotTokensIndex;

    // all SlotData
    SlotData[] private _allSlots;

    // slot => index
    mapping(uint256 => uint256) private _allSlotsIndex;

    // all slot manager list
    address[] private _allSlotManagers;

    // slot manager => index
    mapping(address => uint256) private _allSlotManagersIndex;

    //// events
    event AddedSlotManager(address slotManager);

    /**
     * initialize method, called by proxy
     */
    constructor(
        string memory name_,
        string memory symbol_,
        uint8 decimals_, 
        address initialOwner_
    ) ERC3525(name_, symbol_, decimals_) {
        require(initialOwner_ != address(0), Errors.ZERO_ADDRESS);

        // initialize owner
        _transferOwnership(initialOwner_);
    }

    //// view functions

    function slotCount() public view override returns (uint256) {
        return _allSlots.length;
    }

    function slotByIndex(uint256 index_) external view override returns (uint256) {
        // require(index_ < slotCount(), Errors.INDEX_EXCEEDS);
        return _allSlots[index_].slot;
    }

    function tokenSupplyInSlot(uint256 slot_) public view override returns (uint256) {
        if (!_slotExists(slot_)) {
            return 0;
        }
        return _allSlots[_allSlotsIndex[slot_]].slotTokens.length;
    }

    function tokenInSlotByIndex(uint256 slot_, uint256 index_) external view override returns (uint256) {
        // require(index_ < tokenSupplyInSlot(slot_), Errors.INDEX_EXCEEDS);
        return _allSlots[_allSlotsIndex[slot_]].slotTokens[index_];
    }

    function slotManagerCount() public view override returns (uint256) {
        return _allSlotManagers.length;
    }

    function slotManagerByIndex(uint256 index_) external view override returns (address) {
        // require(index_ < slotManagerCount(), Errors.INDEX_EXCEEDS);
        return _allSlotManagers[index_];
    }

    function managerOf(uint256 slot_) external view override returns (address) {
        require(_slotExists(slot_), Errors.SLOT_NOT_EXISTS);

        return _managerOfSlot(slot_);
    }

    /// state functions

    function claimSlot(uint256 slot_) external override {
        require(_slotManagerExists(_msgSender()), Errors.NOT_SLOT_MANAGER_ROLE);
        require(!_slotExists(slot_), Errors.NOT_MANAGER_OF_SLOT);

        _createSlot(slot_, _msgSender());
    }

    function mint(
        address to_,
        uint256 slot_,
        uint256 value_
    ) external override returns (uint256 tokenId) {
        require(_slotExists(slot_), Errors.SLOT_NOT_EXISTS);

        SlotData storage slotData = _allSlots[_allSlotsIndex[slot_]];
        // check if slot manager of target slot
        require(_msgSender() == slotData.slotManager, Errors.NOT_MANAGER_OF_SLOT);

        tokenId = ERC3525._mint(to_, slot_, value_);
        ERC3525._approve(_msgSender(), tokenId);
    }

    function burn(uint256 tokenId_) external override {
        require(_isApprovedOrOwner(_msgSender(), tokenId_), Errors.NOT_OWNER_NOR_APPROVED);
        ERC3525._burn(tokenId_);
    }

    //// admin functions

    /**
     * 增加产品中心 
     */
    function addSlotManager(address slotManager_, uint256[] calldata slots_) external onlyOwner {
        // require(slotManager_ != address(0), Errors.ZERO_ADDRESS);
        require(!_slotManagerExists(slotManager_), Errors.SLOT_MANAGER_ALREADY_EXISTS);

        // change state
        _allSlotManagersIndex[slotManager_] = _allSlotManagers.length;
        _allSlotManagers.push(slotManager_);

        for (uint i = 0; i < slots_.length; i++) {
            require(!_slotExists(slots_[i]), Errors.NOT_MANAGER_OF_SLOT);
            _createSlot(slots_[i], slotManager_);
        }

        emit AddedSlotManager(slotManager_);
    }

    /**
     * 设置IERC3525MetadataDescriptor
     */
    function setMetadataDescriptor(address metadataDescriptor_) external onlyOwner {
        // require(metadataDescriptor_ != address(0), Errors.ZERO_ADDRESS);

        ERC3525._setMetadataDescriptor(metadataDescriptor_);
    }

    //// internal functions

    function _slotExists(uint256 slot_) private view returns (bool) {
        return _allSlots.length != 0 && _allSlots[_allSlotsIndex[slot_]].slot == slot_;
    }

    function _slotManagerExists(address slotManager_) private view returns (bool) {
        return _allSlotManagers.length != 0 && _allSlotManagers[_allSlotManagersIndex[slotManager_]] == slotManager_;
    }

    function _managerOfSlot(uint256 slot_) private view returns (address) {
        return _allSlots[_allSlotsIndex[slot_]].slotManager;
    }

    function _tokenExistsInSlot(uint256 slot_, uint256 tokenId_) private view returns (bool) {
        SlotData storage slotData = _allSlots[_allSlotsIndex[slot_]];
        return slotData.slotTokens.length > 0 && slotData.slotTokens[_slotTokensIndex[slot_][tokenId_]] == tokenId_;
    }

    function _createSlot(uint256 slot_, address slotManager_) private {
        SlotData memory slotData = SlotData({
            slot: slot_, 
            slotTokens: new uint256[](0),
            slotManager: slotManager_
        });
        _addSlotToAllSlotsEnumeration(slotData);
        emit SlotChanged(0, 0, slot_);
    }

    function _beforeValueTransfer(
        address from_,
        address to_,
        uint256 fromTokenId_,
        uint256 toTokenId_,
        uint256 slot_,
        uint256 value_
    ) internal override {
        // call slotManager after all states updated 
        address slotManager = _managerOfSlot(slot_);
        if (slotManager.isContract() && IERC165(slotManager).supportsInterface(type(ISlotManager).interfaceId)) {
            ISlotManager(slotManager).beforeValueTransfer(from_, to_, fromTokenId_, toTokenId_, slot_, value_);
        } 

        super._beforeValueTransfer(from_, to_, fromTokenId_, toTokenId_, slot_, value_);

        //Shh - currently unused
        to_;
        toTokenId_;
        value_;
    }

    function _afterValueTransfer(
        address from_,
        address to_,
        uint256 fromTokenId_,
        uint256 toTokenId_,
        uint256 slot_,
        uint256 value_
    ) internal override {
        if (from_ == address(0) && fromTokenId_ == 0 && !_tokenExistsInSlot(slot_, toTokenId_)) {
            _addTokenToSlotEnumeration(slot_, toTokenId_);
        } else if (to_ == address(0) && toTokenId_ == 0 && _tokenExistsInSlot(slot_, fromTokenId_)) {
            _removeTokenFromSlotEnumeration(slot_, fromTokenId_);
        }

        //Shh - currently unused
        value_;

        super._afterValueTransfer(from_, to_, fromTokenId_, toTokenId_, slot_, value_);

        // call slotManager after all states updated 
        address slotManager = _managerOfSlot(slot_);
        if (slotManager.isContract() && IERC165(slotManager).supportsInterface(type(ISlotManager).interfaceId)) {
            ISlotManager(slotManager).afterValueTransfer(from_, to_, fromTokenId_, toTokenId_, slot_, value_);
        } 
    }

    function _addSlotToAllSlotsEnumeration(SlotData memory slotData) private {
        _allSlotsIndex[slotData.slot] = _allSlots.length;
        _allSlots.push(slotData);
    }

    function _addTokenToSlotEnumeration(uint256 slot_, uint256 tokenId_) private {
        SlotData storage slotData = _allSlots[_allSlotsIndex[slot_]];
        _slotTokensIndex[slot_][tokenId_] = slotData.slotTokens.length;
        slotData.slotTokens.push(tokenId_);
    }

    function _removeTokenFromSlotEnumeration(uint256 slot_, uint256 tokenId_) private {
        SlotData storage slotData = _allSlots[_allSlotsIndex[slot_]];
        uint256 lastTokenIndex = slotData.slotTokens.length - 1;
        uint256 lastTokenId = slotData.slotTokens[lastTokenIndex];
        uint256 tokenIndex = _slotTokensIndex[slot_][tokenId_];

        slotData.slotTokens[tokenIndex] = lastTokenId;
        _slotTokensIndex[slot_][lastTokenId] = tokenIndex;

        delete _slotTokensIndex[slot_][tokenId_];
        slotData.slotTokens.pop();
    }
}
