// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "../ILongVoucher.sol";
import "../IProductCenter.sol";
import "../IVoucherSVG.sol";
import "../utils/StringConverter.sol";

contract VoucherSVG is IVoucherSVG {
    using StringConverter for address;
    using StringConverter for uint256;
    using StringConverter for bytes;

    ILongVoucher public longVoucher;

    constructor(address longVoucher_) {
        longVoucher = ILongVoucher(longVoucher_);
    }

    function generateSVG(uint256 tokenId) external view returns (bytes memory) {
        uint256 productId = longVoucher.slotOf(tokenId);
        IProductCenter productCenter = IProductCenter(longVoucher.managerOf(productId));

        IProductCenter.ProductParameters memory parameters = productCenter.getProductParameters(productId);
        bool isOnline = block.number > parameters.endSubscriptionBlock;

        return
            abi.encodePacked(
                '<svg width="400px" height="267px" viewBox="0 0 400 267" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">',
                '<g stroke-width="1" fill="none" fill-rule="evenodd" font-family="Arial">',
                _generateBackground(),
                _generateTitle(tokenId),
                _generateContent(productCenter, productId, tokenId),
                _generateLogo(),
                isOnline ? "" : _generateSubscriptionFlag(),
                "</g>",
                "</svg>"
            );
    }

    function shortAddress(address addr) private pure returns (bytes memory) {
        return bytes(addr.toString()).trim(32);
    }

    function _generateBackground() internal pure returns (string memory) {
        return
            string(
                abi.encodePacked(
                    '<path d="M13.671.414C7.852 2.244 2.163 7.974.402 13.782c-.577 1.901-.604 236.944-.027 238.821 1.159 3.776 2.369 5.645 5.808 8.966 3.235 3.125 5.265 4.182 9.49 4.94 2.876.517 369.05.178 370.507-.342 6.33-2.262 11.636-7.584 13.418-13.46.348-1.145.397-15.813.399-119.352L400 15.308l-.545-1.712c-1.889-5.939-7.43-11.263-13.847-13.307-1.49-.474-370.425-.35-371.937.125" fill="#134c6b"/>',
                    '<path d="M.026 7.41c.024 6.638.064 7.29.388 6.261C2.223 7.918 7.918 2.223 13.671.414 14.7.09 14.048.05 7.41.026L0 0l.026 7.41M385.714.308c6.351 2.104 11.815 7.351 13.723 13.177l.525 1.602.019-7.544L400 0l-7.543.021c-5.384.015-7.314.097-6.743.287M.021 259.346 0 267.023h400l-.026-7.677c-.024-6.863-.065-7.555-.388-6.529-1.83 5.821-7.144 11.112-13.406 13.35-1.457.52-367.631.859-370.507.342-7.163-1.286-12.846-6.48-15.364-14.039-.191-.573-.273 1.381-.288 6.876" fill="#f6fbfb"/>'
                )
            );
    }

    function _generateTitle(
        uint256 tokenId
    ) internal view returns (string memory) {
        string memory tokenIdStr = tokenId.toString();
        uint256 tokenIdLeftMargin = 335 - 14 * bytes(tokenIdStr).length;

        bytes memory amount = _formatValue(
            longVoucher.balanceOf(tokenId),
            longVoucher.valueDecimals()
        );
        uint256 amountLeftMargin = 240 - 17 * amount.length;

        return
            string(
                abi.encodePacked(
                    '<g transform="translate(30, 30)" fill="#FFFFFF" fill-rule="nonzero">',
                    '<text font-family="Arial" font-size="24">',
                    abi.encodePacked(
                        '<tspan x="',
                        tokenIdLeftMargin.toString(),
                        '" y="10"># ',
                        tokenIdStr,
                        "</tspan>"
                    ),
                    "</text>",
                    '<text font-family="Arial" font-size="32">',
                    abi.encodePacked(
                        '<tspan x="',
                        amountLeftMargin.toString(),
                        '" y="90">',
                        amount,
                        "</tspan>"
                    ),
                    "</text>",
                    '<text font-family="Arial" font-weight="bold" font-size="18"><tspan x="30" y="10">Voucher</tspan></text>',
                    '<text font-family="Arial" font-size="18"><tspan x="260" y="86">FIL</tspan></text>',
                    "</g>"
                )
            );
    }

    function _generateContent(IProductCenter productCenter, uint256 productId, uint256 voucherId) internal view returns (string memory) {
        IProductCenter.ProductParameters memory parameters = productCenter.getProductParameters(productId);

        uint256 interest = productCenter.voucherInterest(voucherId);
        bytes memory head = abi.encodePacked(
            shortAddress(address(productCenter)), 
            ' # ', 
            productId.toString()
        );

        bool redeemable = block.number >= parameters.endSubscriptionBlock + parameters.minHoldingDuration;

        return
            string(
                abi.encodePacked(
                    '<g transform="translate(10, 160)">',
                    '<rect fill="#000000" opacity="0.1" x="0" y="0" width="380" height="100" rx="15"></rect>',
                    '<text fill-rule="nonzero" font-family="Arial" font-size="14" font-weight="bold" fill="#FFFFFF"><tspan x="10" y="18">PRODUCT: ',
                    head,
                    '</tspan></text>',
                    '<text fill-rule="nonzero" font-family="Arial" font-size="14" fill="#FFFFFF"><tspan x="30" y="42">APR: ', 
                    parameters.interestRate.nowAPR(parameters.beginSubscriptionBlock, parameters.endSubscriptionBlock),
                    '</tspan></text>',
                    '<text fill-rule="nonzero" font-family="Arial" font-size="14" fill="#FFFFFF"><tspan x="30" y="64">ACCRUED INTEREST: ',
                    abi.encodePacked(_formatValue(interest, longVoucher.valueDecimals()), ' FIL'),
                    '</tspan></text>',
                    '<text fill-rule="nonzero" font-family="Arial" font-size="14" fill="#FFFFFF"><tspan x="30" y="86">REDEEMABLE: ',
                    redeemable ? 'TRUE' : 'FALSE',
                    '</tspan></text>',
                    "</g>"
                )
            );
    }

    function _generateSubscriptionFlag() internal pure returns (string memory) {
        return
            string(
                abi.encodePacked(
                    '<g transform="translate(130, 20)">',
                    '<svg width="30" height="30" viewBox="0 0 384 384" class="icon" xmlns="http://www.w3.org/2000/svg"><path d="M191.962 68.625c-68.175 0-123.413 55.275-123.413 123.413S123.825 315.45 191.962 315.45c68.175 0 123.413-55.275 123.413-123.413S260.1 68.625 191.962 68.625zm0 219.45c-52.95 0-96-43.05-96-96s43.05-96 96-96 96 43.05 96 96-43.088 96-96 96z" fill="#0F1F3C"/><path d="M205.725 137.137h-27.45v60.525l45.188 45.188 19.388-19.388-37.125-37.125z" fill="#0F1F3C"/></svg>',
                    '</g>'
                )
            );
    }

    function _generateLogo() internal pure returns (string memory) {
        return
            string(
                abi.encodePacked(
                    '<g transform="translate(10, 10)" fill-rule="evenodd">',
                    '<svg viewBox="0 0 7.813 8.353" width="45" height="48.111"><path d="M7.108 3.994a3.129 3.129 0 0 1-3.08 3.123A3.13 3.13 0 1 1 4.047.859a3.129 3.129 0 0 1 3.061 3.135zM1.853 6.152c.042.003.072.005.1.005.26 0 .52-.004.78.001a1.381 1.381 0 0 0 .542-.098 1.389 1.389 0 0 0 .837-.866c.169-.489.328-.981.49-1.472.015-.045.037-.064.087-.063.095.004.266-.001.361.003l.004-.021c.027-.107.072-.256.102-.362l.063-.233h-.403l.018-.022c.046-.053.087-.111.139-.157a.631.631 0 0 1 .431-.15 22.005 22.005 0 0 1 .583.003c.056.001.087-.018.104-.072.03-.092.067-.182.1-.273l.11-.298c-.042-.002-.072-.005-.103-.005-.256 0-.511.006-.766-.002a1.393 1.393 0 0 0-.708.169 1.402 1.402 0 0 0-.658.736c-.023.059-.048.076-.105.073l-.365-.008a39.278 39.278 0 0 1-.17.62h.416c-.042.132-.082.248-.117.366-.015.048-.039.066-.092.065-.246-.003-.492-.002-.739-.003-.017 0-.034-.003-.058-.006l.601-2.009-.623-.004s-.295.986-.431 1.447c-.07.237-.148.473-.2.714-.069.328.147.484.437.479.283-.005.565-.005.847-.007.006 0 .013.004.027.01-.037.111-.081.219-.112.331-.081.292-.325.468-.636.466-.197-.002-.393.001-.59-.001h-.058l-.119.31-.126.333zM4.367 4.7l.042.002c.35 0 .699 0 1.049.002h.048c.042-.124.098-.302.14-.425l.061-.182c-.017-.003-.023-.006-.03-.006-.354 0-.753 0-1.107.003 0 0-.006.025-.013.046-.036.092-.064.187-.096.28l-.094.282z" style="fill:#008cfa"/></svg>',
                    "</g>"
                )
            );
    }

    function _formatValue(
        uint256 value,
        uint8 decimals
    ) private pure returns (bytes memory) {
        return value.uint2decimal(decimals).trim(decimals - 4);
    }
}
