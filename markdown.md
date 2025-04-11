## Contracts
| Contract Name | Address |
|--------------|--------------|
| PancakeFactory | 0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73 |
| PancakeRouter | 0x10ED43C718714eb63d5aA57B78B54704E256024E |
| GnosisSafeProxy | 0xcEba60280fb0ecd9A5A26A1552B90944770a4a0e |


## Permission
| Contract | Function | Impact | Owner |
|-------------|------------|-------------------------|-------------------|
| PancakeFactory | setFeeTo | ... | [] |
| PancakeFactory | setFeeToSetter | ... | [] |
| PancakeRouter | receive | ... | [] |
| PancakeRouter | addLiquidity | ... | ['ensure'] |
| PancakeRouter | addLiquidityETH | ... | ['ensure'] |
| PancakeRouter | removeLiquidity | ... | ['ensure'] |
| PancakeRouter | removeLiquidityETH | ... | ['ensure'] |
| PancakeRouter | removeLiquidityWithPermit | ... | ['ensure'] |
| PancakeRouter | removeLiquidityETHWithPermit | ... | ['ensure'] |
| PancakeRouter | removeLiquidityETHSupportingFeeOnTransferTokens | ... | ['ensure'] |
| PancakeRouter | removeLiquidityETHWithPermitSupportingFeeOnTransferTokens | ... | ['ensure'] |
| PancakeRouter | swapExactTokensForTokens | ... | ['ensure'] |
| PancakeRouter | swapTokensForExactTokens | ... | ['ensure'] |
| PancakeRouter | swapExactETHForTokens | ... | ['ensure'] |
| PancakeRouter | swapTokensForExactETH | ... | ['ensure'] |
| PancakeRouter | swapExactTokensForETH | ... | ['ensure'] |
| PancakeRouter | swapETHForExactTokens | ... | ['ensure'] |
| PancakeRouter | swapExactTokensForTokensSupportingFeeOnTransferTokens | ... | ['ensure'] |
| PancakeRouter | swapExactETHForTokensSupportingFeeOnTransferTokens | ... | ['ensure'] |
| PancakeRouter | swapExactTokensForETHSupportingFeeOnTransferTokens | ... | ['ensure'] |
