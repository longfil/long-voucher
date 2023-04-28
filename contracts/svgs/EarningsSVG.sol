// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "../ILongVoucher.sol";
import "../IVoucherSVG.sol";
import "../utils/StringConverter.sol";

contract EarningsSVG is IVoucherSVG {
    using StringConverter for uint256;
    using StringConverter for bytes;

    ILongVoucher public longVoucher;

    constructor(address longVoucher_) {
        longVoucher = ILongVoucher(longVoucher_);
    }

    function generateSVG(uint256 tokenId) external view returns (bytes memory) {
        return
            abi.encodePacked(
                '<svg width="400px" height="267px" viewBox="0 0 400 267" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">',
                '<g stroke-width="1" fill="none" fill-rule="evenodd" font-family="Arial">',
                _generateBackground(),
                _generateTitle(tokenId),
                // _generateContent(),
                _generateLogo(),
                "</g>",
                "</svg>"
            );
    }

    function _generateBackground() internal pure returns (string memory) {
        return
            string(
                abi.encodePacked(
                    '<path d="M.014 7.543c.015 8.116-.053 7.861 1.173 4.424C2.816 7.397 8.322 2.327 13.485.643l1.869-.609L7.677.017 0 0l.014 7.543M384.802.107c.061.059.87.356 1.798.659 6.504 2.127 12.34 9.254 12.583 15.367.089 2.243.163 2.701.305 1.891.223-1.277.077 228.517-.148 232.176-.424 6.88-6.345 14.012-13.126 15.808l-1.301.345 1.736.222c.954.122 4.349.279 7.543.349l5.808.128V0h-7.655c-4.21 0-7.604.048-7.543.107M0 259.69v7.353l5.541-.119c3.047-.065 6.321-.22 7.276-.344l1.736-.225-1.202-.364c-5.494-1.664-11.582-7.807-12.67-12.787-.488-2.235-.681-.399-.681 6.486" fill="#f1fafa"/>',
                    '<path d="M13.485.643C7.779 2.504 2.763 7.435.764 13.146L0 15.328v118.504c0 72.006.096 118.504.246 118.504.135 0 .331.391.435.868 1.081 4.946 6.73 10.702 12.534 12.769l1.338.477-1.469.023c-.808.013-1.649.14-1.869.283-.259.167 66.507.253 188.651.244 105.672-.008 188.817-.116 188.519-.244-.294-.127-1.195-.249-2.003-.273l-1.469-.043 1.469-.466c7.045-2.236 12.536-8.919 12.958-15.774.225-3.659.371-233.453.148-232.176-.142.81-.216.352-.305-1.891-.247-6.225-5.981-13.135-12.828-15.459l-1.976-.67-184.513.015L15.354.034l-1.869.609" fill="#34bcb4"/>'
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
                    '<text font-family="Arial" font-size="24" fill="#565963">',
                    abi.encodePacked(
                        '<tspan x="',
                        tokenIdLeftMargin.toString(),
                        '" y="210"># ',
                        tokenIdStr,
                        "</tspan>"
                    ),
                    "</text>",
                    '<text font-family="Arial" font-size="32">',
                    abi.encodePacked(
                        '<tspan x="',
                        amountLeftMargin.toString(),
                        '" y="110">',
                        amount,
                        "</tspan>"
                    ),
                    "</text>",
                    '<text font-family="Arial" font-weight="bold" font-size="18" fill="#565963"><tspan x="30" y="10">Earnings</tspan></text>',
                    '<text font-family="Arial" font-size="24"><tspan x="310" y="106">FIL</tspan></text>',
                    "</g>"
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
