# LongFil Platform
LongFil Platform is a lending platform and a SFT (Semi-Fungible Token) issuance platform.
LongFil Platform innovatively uses [ERC3525](https://eips.ethereum.org/EIPS/eip-3525) as the underlying technology to bring more usability and flexibility to Defi.

## Product & ProductCenter
Product in LongFil Platform is like a fund, which has attributes such as subscription range, total amount, minimum purchase amount, minimum holding time, interest rate, etc. ProductCenter manages the life cycle of the product. After purchasing the product, the user will receive a corresponding share of SFT, and can redeem the principal and interest with SFT in the future. After the product subscription period ends, the funds raised will be used for lending, such as lending to Filecoin miners, etc.

### Roles
- Operator  
Has the priviledges to create products and manage product parameters.
- Cashier  
Has the priviledges to issue loans

## Recommendation & RecommendationCenter
coming soon!

## Contracts & Deployment 
| name  | description  |
| --- | --- |
| LongVoucher | Voucher contract based on ERC3525 |
| LongVoucherMetadataDescriptor | ERC3525 metadata |
| Recommendation | Matains recommendation relationships  |
| RecommendationCenter | Referrer's equities and earnings management |
| ProductCenter | Product management |
| TieredInterestRate | Tiered interest rate |
| ProductCenterDescriptor | ProductCenter & Product metadata provider |
| QualSVG | SVG source of recommendation qualification NFT |
| EarningsSVG | SVG source of referrer earnings SFT |
| VoucherSVG | SVG source of voucher |
| PlainMetadataProvider | Plain metadata provider |
| SimpleCashPool | Simple cash pool |
### Filecoin Hyperspace
| name  | address  |
| --- | --- |
| LongVoucher | 0x0866439f4b8157a7031F1918d0eAC9cAA4933443 |
| LongVoucherMetadataDescriptor | 0x090feBBFB0F33B3c14b691EFF12A244D723D6397 |
| Recommendation | 0x262a305De600C59D2d07171A5E23dac1fc83Ca76 |
| RecommendationCenter | 0x01B831a3CB911306FCd272fb2A26E58D9DD015F5 |
| ProductCenter | 0x0f1e1d17957DfE28ac1472D893e1a06e3605dDBA |
| TieredInterestRate | 0xcC02aA358Fc74FC0542b21E8D896cCBCf9919274 |
| ProductCenterDescriptor | 0xfce0a3beB53d9aa398f3f56f5FFCE2628e640D6A |
| QualSVG | 0x9175225B6DDf676A1C7C038845CaF21d2D060995 |
| EarningsSVG | 0xF0402287f1221130b7139CcF64622e59B3B83E3f |
| VoucherSVG | 0x2d8713402F3E3496447eB3057CBF0fe8D114F6C4 |
| PlainMetadataProvider(Recommendation) | 0x9e191dC0159eeececEd09Ed4d6F65a17943195AA |
| PlainMetadataProvider(RecommendationCenter)  | 0x967330b5F053a81BDE6D742BE7Adf8A30280c5b5 |
| SimpleCashPool | 0x00C4A4c6218E75EFC4e923cB92910E822e1a4DE6 |

### Filecoin Mainnet
| name  | address  |
| --- | --- |
| LongVoucher | 0x138553d5041fffbe1E26A7Ba1fB318B66875b318 |
| LongVoucherMetadataDescriptor | 0x4357438a4102d56E28B8f9fefe8EE31dDA7D7c55 |
| Recommendation | 0x19c3cD3957E02d4D839EFdD82BDd64F32E907daC |
| RecommendationCenter | 0xFB076865A6214bc4eaA61B9152C8B0111472F488 |
| ProductCenter | 0xcAf6BC6A1a800C6EB784D66A984552687Ae6461d |
| TieredInterestRate | 0x91bAa01879177dC874839f42cDB41CFB414Ff7B9 |
| ProductCenterDescriptor | 0x7ade06C468a7167A54b256639b4dC2eC5C7eAEfB |
| QualSVG | 0x934f2DF38C7F6F275341ED5BF60d9252D04e4949 |
| EarningsSVG | 0x282BAb089Ddf19d9B9459b34111f5Ac3460B1F6F |
| VoucherSVG | 0x1805a5F4D62F8Ade17eDfFa12239C51D39F24205 |
| PlainMetadataProvider(Recommendation) | 0x1c2dd8B465d8BF44DCb90A92bCb9402a5c11866E |
| PlainMetadataProvider(RecommendationCenter) | 0x024124b60c10222915b86920486bbEAc97dca10b |
| SimpleCashPool | 0xEAdc30f6A9a950B819b1DEd8d6255A2a5Ed1A616 |
