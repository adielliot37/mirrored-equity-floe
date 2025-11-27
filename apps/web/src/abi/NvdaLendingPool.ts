export const nvdaLendingPoolAbi = [
  {
    "inputs": [{"internalType": "uint256","name": "amount","type": "uint256"}],
    "name": "depositCollateral",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [{"internalType": "uint256","name": "amount","type": "uint256"}],
    "name": "withdrawCollateral",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [{"internalType": "uint256","name": "amount","type": "uint256"}],
    "name": "depositUSDC",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [{"internalType": "uint256","name": "amount","type": "uint256"}],
    "name": "withdrawUSDC",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [
      {"internalType": "uint256","name": "amount","type": "uint256"},
      {"internalType": "uint256","name": "durationSeconds","type": "uint256"}
    ],
    "name": "borrow",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [{"internalType": "uint256","name": "amount","type": "uint256"}],
    "name": "repay",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [
      {"internalType": "address","name": "user","type": "address"},
      {"internalType": "uint256","name": "repayAmount","type": "uint256"}
    ],
    "name": "liquidate",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [{"internalType": "address","name": "user","type": "address"}],
    "name": "getUserSnapshot",
    "outputs": [
      {"internalType": "uint256","name": "collateralNVDA","type": "uint256"},
      {"internalType": "uint256","name": "collateralUSD","type": "uint256"},
      {"internalType": "uint256","name": "debtUSDC","type": "uint256"},
      {"internalType": "uint256","name": "maxBorrowUSDC","type": "uint256"},
      {"internalType": "uint256","name": "healthFactor","type": "uint256"},
      {"internalType": "uint40","name": "lastBorrowTimestamp","type": "uint40"},
      {"internalType": "uint40","name": "durationSeconds","type": "uint40"}
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "getRates",
    "outputs": [
      {"internalType": "uint256","name": "utilization","type": "uint256"},
      {"internalType": "uint256","name": "borrowAPR","type": "uint256"},
      {"internalType": "uint256","name": "supplyAPR","type": "uint256"}
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [{"internalType": "address","name": "user","type": "address"}],
    "name": "getLenderBalance",
    "outputs": [{"internalType": "uint256","name": "","type": "uint256"}],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [{"internalType": "address","name": "user","type": "address"}],
    "name": "getUserDebt",
    "outputs": [{"internalType": "uint256","name": "","type": "uint256"}],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [{"internalType": "address","name": "user","type": "address"}],
    "name": "getCollateralValueUSD",
    "outputs": [{"internalType": "uint256","name": "","type": "uint256"}],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [{"internalType": "address","name": "user","type": "address"}],
    "name": "getHealthFactor",
    "outputs": [{"internalType": "uint256","name": "","type": "uint256"}],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [{"internalType": "address","name": "user","type": "address"}],
    "name": "maxBorrowable",
    "outputs": [{"internalType": "uint256","name": "","type": "uint256"}],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [{"internalType": "uint256","name": "borrowAmount","type": "uint256"}],
    "name": "collateralRequired",
    "outputs": [{"internalType": "uint256","name": "","type": "uint256"}],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [{"internalType": "address","name": "user","type": "address"}],
    "name": "getBorrowerPosition",
    "outputs": [
      {"internalType": "uint256","name": "debtUSDC","type": "uint256"},
      {"internalType": "uint256","name": "principalUSDC","type": "uint256"},
      {"internalType": "uint256","name": "interestUSDC","type": "uint256"},
      {"internalType": "uint256","name": "maxBorrowUSDC","type": "uint256"},
      {"internalType": "uint256","name": "healthFactor","type": "uint256"}
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [{"internalType": "address","name": "user","type": "address"}],
    "name": "getLenderPosition",
    "outputs": [
      {"internalType": "uint256","name": "balance","type": "uint256"},
      {"internalType": "uint256","name": "principal","type": "uint256"},
      {"internalType": "uint256","name": "interest","type": "uint256"}
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "availableLiquidity",
    "outputs": [{"internalType": "uint256","name": "","type": "uint256"}],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "getPoolStats",
    "outputs": [
      {"internalType": "uint256","name": "deposits","type": "uint256"},
      {"internalType": "uint256","name": "debt","type": "uint256"},
      {"internalType": "uint256","name": "liquidity","type": "uint256"}
    ],
    "stateMutability": "view",
    "type": "function"
  }
] as const;

