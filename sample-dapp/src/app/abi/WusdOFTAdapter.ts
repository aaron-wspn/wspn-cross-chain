// NOTE: Please keep this in sync with the contract ABI in the lz-oapp project
export const wusdOftAdapterAbi = [
  {
    type: "constructor",
    inputs: [
      { name: "_token", type: "address", internalType: "address" },
      { name: "_lzEndpoint", type: "address", internalType: "address" },
      {
        name: "defaultAdmin",
        type: "address",
        internalType: "address",
      },
      { name: "_delegate", type: "address", internalType: "address" },
    ],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "AUTHORIZER_ROLE",
    inputs: [],
    outputs: [{ name: "", type: "bytes32", internalType: "bytes32" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "CONTRACT_ADMIN_ROLE",
    inputs: [],
    outputs: [{ name: "", type: "bytes32", internalType: "bytes32" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "DEFAULT_ADMIN_ROLE",
    inputs: [],
    outputs: [{ name: "", type: "bytes32", internalType: "bytes32" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "DOMAIN_SEPARATOR",
    inputs: [],
    outputs: [{ name: "", type: "bytes32", internalType: "bytes32" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "EMBARGO_ROLE",
    inputs: [],
    outputs: [{ name: "", type: "bytes32", internalType: "bytes32" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "PAUSER_ROLE",
    inputs: [],
    outputs: [{ name: "", type: "bytes32", internalType: "bytes32" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "SALVAGE_ROLE",
    inputs: [],
    outputs: [{ name: "", type: "bytes32", internalType: "bytes32" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "SEND",
    inputs: [],
    outputs: [{ name: "", type: "uint16", internalType: "uint16" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "SEND_AND_CALL",
    inputs: [],
    outputs: [{ name: "", type: "uint16", internalType: "uint16" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "SEND_AUTHORIZATION_TYPEHASH",
    inputs: [],
    outputs: [{ name: "", type: "bytes32", internalType: "bytes32" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "SEND_PARAM_TYPEHASH",
    inputs: [],
    outputs: [{ name: "", type: "bytes32", internalType: "bytes32" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "accessRegistry",
    inputs: [],
    outputs: [
      {
        name: "",
        type: "address",
        internalType: "contract IAccessRegistry",
      },
    ],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "accessRegistryUpdate",
    inputs: [
      {
        name: "_accessRegistry",
        type: "address",
        internalType: "address",
      },
    ],
    outputs: [],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "allowInitializePath",
    inputs: [
      {
        name: "origin",
        type: "tuple",
        internalType: "struct Origin",
        components: [
          { name: "srcEid", type: "uint32", internalType: "uint32" },
          { name: "sender", type: "bytes32", internalType: "bytes32" },
          { name: "nonce", type: "uint64", internalType: "uint64" },
        ],
      },
    ],
    outputs: [{ name: "", type: "bool", internalType: "bool" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "approvalRequired",
    inputs: [],
    outputs: [{ name: "", type: "bool", internalType: "bool" }],
    stateMutability: "pure",
  },
  {
    type: "function",
    name: "combineOptions",
    inputs: [
      { name: "_eid", type: "uint32", internalType: "uint32" },
      { name: "_msgType", type: "uint16", internalType: "uint16" },
      { name: "_extraOptions", type: "bytes", internalType: "bytes" },
    ],
    outputs: [{ name: "", type: "bytes", internalType: "bytes" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "decimalConversionRate",
    inputs: [],
    outputs: [{ name: "", type: "uint256", internalType: "uint256" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "eip712Domain",
    inputs: [],
    outputs: [
      { name: "fields", type: "bytes1", internalType: "bytes1" },
      { name: "name", type: "string", internalType: "string" },
      { name: "version", type: "string", internalType: "string" },
      { name: "chainId", type: "uint256", internalType: "uint256" },
      {
        name: "verifyingContract",
        type: "address",
        internalType: "address",
      },
      { name: "salt", type: "bytes32", internalType: "bytes32" },
      {
        name: "extensions",
        type: "uint256[]",
        internalType: "uint256[]",
      },
    ],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "embargoedAccounts",
    inputs: [],
    outputs: [{ name: "", type: "address[]", internalType: "address[]" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "embargoedBalance",
    inputs: [{ name: "_account", type: "address", internalType: "address" }],
    outputs: [{ name: "", type: "uint256", internalType: "uint256" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "endpoint",
    inputs: [],
    outputs: [
      {
        name: "",
        type: "address",
        internalType: "contract ILayerZeroEndpointV2",
      },
    ],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "enforcedOptions",
    inputs: [
      { name: "eid", type: "uint32", internalType: "uint32" },
      { name: "msgType", type: "uint16", internalType: "uint16" },
    ],
    outputs: [{ name: "enforcedOption", type: "bytes", internalType: "bytes" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "getRoleAdmin",
    inputs: [{ name: "role", type: "bytes32", internalType: "bytes32" }],
    outputs: [{ name: "", type: "bytes32", internalType: "bytes32" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "grantRole",
    inputs: [
      { name: "role", type: "bytes32", internalType: "bytes32" },
      { name: "account", type: "address", internalType: "address" },
    ],
    outputs: [],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "hasRole",
    inputs: [
      { name: "role", type: "bytes32", internalType: "bytes32" },
      { name: "account", type: "address", internalType: "address" },
    ],
    outputs: [{ name: "", type: "bool", internalType: "bool" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "isComposeMsgSender",
    inputs: [
      {
        name: "",
        type: "tuple",
        internalType: "struct Origin",
        components: [
          { name: "srcEid", type: "uint32", internalType: "uint32" },
          { name: "sender", type: "bytes32", internalType: "bytes32" },
          { name: "nonce", type: "uint64", internalType: "uint64" },
        ],
      },
      { name: "", type: "bytes", internalType: "bytes" },
      { name: "_sender", type: "address", internalType: "address" },
    ],
    outputs: [{ name: "", type: "bool", internalType: "bool" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "isPeer",
    inputs: [
      { name: "_eid", type: "uint32", internalType: "uint32" },
      { name: "_peer", type: "bytes32", internalType: "bytes32" },
    ],
    outputs: [{ name: "", type: "bool", internalType: "bool" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "lzReceive",
    inputs: [
      {
        name: "_origin",
        type: "tuple",
        internalType: "struct Origin",
        components: [
          { name: "srcEid", type: "uint32", internalType: "uint32" },
          { name: "sender", type: "bytes32", internalType: "bytes32" },
          { name: "nonce", type: "uint64", internalType: "uint64" },
        ],
      },
      { name: "_guid", type: "bytes32", internalType: "bytes32" },
      { name: "_message", type: "bytes", internalType: "bytes" },
      { name: "_executor", type: "address", internalType: "address" },
      { name: "_extraData", type: "bytes", internalType: "bytes" },
    ],
    outputs: [],
    stateMutability: "payable",
  },
  {
    type: "function",
    name: "lzReceiveAndRevert",
    inputs: [
      {
        name: "_packets",
        type: "tuple[]",
        internalType: "struct InboundPacket[]",
        components: [
          {
            name: "origin",
            type: "tuple",
            internalType: "struct Origin",
            components: [
              {
                name: "srcEid",
                type: "uint32",
                internalType: "uint32",
              },
              {
                name: "sender",
                type: "bytes32",
                internalType: "bytes32",
              },
              { name: "nonce", type: "uint64", internalType: "uint64" },
            ],
          },
          { name: "dstEid", type: "uint32", internalType: "uint32" },
          {
            name: "receiver",
            type: "address",
            internalType: "address",
          },
          { name: "guid", type: "bytes32", internalType: "bytes32" },
          { name: "value", type: "uint256", internalType: "uint256" },
          {
            name: "executor",
            type: "address",
            internalType: "address",
          },
          { name: "message", type: "bytes", internalType: "bytes" },
          { name: "extraData", type: "bytes", internalType: "bytes" },
        ],
      },
    ],
    outputs: [],
    stateMutability: "payable",
  },
  {
    type: "function",
    name: "lzReceiveSimulate",
    inputs: [
      {
        name: "_origin",
        type: "tuple",
        internalType: "struct Origin",
        components: [
          { name: "srcEid", type: "uint32", internalType: "uint32" },
          { name: "sender", type: "bytes32", internalType: "bytes32" },
          { name: "nonce", type: "uint64", internalType: "uint64" },
        ],
      },
      { name: "_guid", type: "bytes32", internalType: "bytes32" },
      { name: "_message", type: "bytes", internalType: "bytes" },
      { name: "_executor", type: "address", internalType: "address" },
      { name: "_extraData", type: "bytes", internalType: "bytes" },
    ],
    outputs: [],
    stateMutability: "payable",
  },
  {
    type: "function",
    name: "msgInspector",
    inputs: [],
    outputs: [{ name: "", type: "address", internalType: "address" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "nextNonce",
    inputs: [
      { name: "", type: "uint32", internalType: "uint32" },
      { name: "", type: "bytes32", internalType: "bytes32" },
    ],
    outputs: [{ name: "nonce", type: "uint64", internalType: "uint64" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "nonces",
    inputs: [{ name: "owner", type: "address", internalType: "address" }],
    outputs: [{ name: "", type: "uint256", internalType: "uint256" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "oApp",
    inputs: [],
    outputs: [{ name: "", type: "address", internalType: "address" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "oAppVersion",
    inputs: [],
    outputs: [
      { name: "senderVersion", type: "uint64", internalType: "uint64" },
      {
        name: "receiverVersion",
        type: "uint64",
        internalType: "uint64",
      },
    ],
    stateMutability: "pure",
  },
  {
    type: "function",
    name: "oftVersion",
    inputs: [],
    outputs: [
      { name: "interfaceId", type: "bytes4", internalType: "bytes4" },
      { name: "version", type: "uint64", internalType: "uint64" },
    ],
    stateMutability: "pure",
  },
  {
    type: "function",
    name: "owner",
    inputs: [],
    outputs: [{ name: "", type: "address", internalType: "address" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "pause",
    inputs: [],
    outputs: [],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "paused",
    inputs: [],
    outputs: [{ name: "", type: "bool", internalType: "bool" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "peers",
    inputs: [{ name: "eid", type: "uint32", internalType: "uint32" }],
    outputs: [{ name: "peer", type: "bytes32", internalType: "bytes32" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "preCrime",
    inputs: [],
    outputs: [{ name: "", type: "address", internalType: "address" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "quoteOFT",
    inputs: [
      {
        name: "_sendParam",
        type: "tuple",
        internalType: "struct SendParam",
        components: [
          { name: "dstEid", type: "uint32", internalType: "uint32" },
          { name: "to", type: "bytes32", internalType: "bytes32" },
          {
            name: "amountLD",
            type: "uint256",
            internalType: "uint256",
          },
          {
            name: "minAmountLD",
            type: "uint256",
            internalType: "uint256",
          },
          {
            name: "extraOptions",
            type: "bytes",
            internalType: "bytes",
          },
          { name: "composeMsg", type: "bytes", internalType: "bytes" },
          { name: "oftCmd", type: "bytes", internalType: "bytes" },
        ],
      },
    ],
    outputs: [
      {
        name: "oftLimit",
        type: "tuple",
        internalType: "struct OFTLimit",
        components: [
          {
            name: "minAmountLD",
            type: "uint256",
            internalType: "uint256",
          },
          {
            name: "maxAmountLD",
            type: "uint256",
            internalType: "uint256",
          },
        ],
      },
      {
        name: "oftFeeDetails",
        type: "tuple[]",
        internalType: "struct OFTFeeDetail[]",
        components: [
          {
            name: "feeAmountLD",
            type: "int256",
            internalType: "int256",
          },
          {
            name: "description",
            type: "string",
            internalType: "string",
          },
        ],
      },
      {
        name: "oftReceipt",
        type: "tuple",
        internalType: "struct OFTReceipt",
        components: [
          {
            name: "amountSentLD",
            type: "uint256",
            internalType: "uint256",
          },
          {
            name: "amountReceivedLD",
            type: "uint256",
            internalType: "uint256",
          },
        ],
      },
    ],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "quoteSend",
    inputs: [
      {
        name: "_sendParam",
        type: "tuple",
        internalType: "struct SendParam",
        components: [
          { name: "dstEid", type: "uint32", internalType: "uint32" },
          { name: "to", type: "bytes32", internalType: "bytes32" },
          {
            name: "amountLD",
            type: "uint256",
            internalType: "uint256",
          },
          {
            name: "minAmountLD",
            type: "uint256",
            internalType: "uint256",
          },
          {
            name: "extraOptions",
            type: "bytes",
            internalType: "bytes",
          },
          { name: "composeMsg", type: "bytes", internalType: "bytes" },
          { name: "oftCmd", type: "bytes", internalType: "bytes" },
        ],
      },
      { name: "_payInLzToken", type: "bool", internalType: "bool" },
    ],
    outputs: [
      {
        name: "msgFee",
        type: "tuple",
        internalType: "struct MessagingFee",
        components: [
          {
            name: "nativeFee",
            type: "uint256",
            internalType: "uint256",
          },
          {
            name: "lzTokenFee",
            type: "uint256",
            internalType: "uint256",
          },
        ],
      },
    ],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "recoverEmbargo",
    inputs: [
      { name: "embargoed", type: "address", internalType: "address" },
      { name: "_to", type: "address", internalType: "address" },
    ],
    outputs: [],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "releaseEmbargo",
    inputs: [{ name: "embargoed", type: "address", internalType: "address" }],
    outputs: [],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "renounceOwnership",
    inputs: [],
    outputs: [],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "renounceRole",
    inputs: [
      { name: "role", type: "bytes32", internalType: "bytes32" },
      { name: "account", type: "address", internalType: "address" },
    ],
    outputs: [],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "revokeRole",
    inputs: [
      { name: "role", type: "bytes32", internalType: "bytes32" },
      { name: "account", type: "address", internalType: "address" },
    ],
    outputs: [],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "salvageERC20",
    inputs: [
      {
        name: "token",
        type: "address",
        internalType: "contract IERC20",
      },
      { name: "amount", type: "uint256", internalType: "uint256" },
    ],
    outputs: [],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "salvageGas",
    inputs: [{ name: "amount", type: "uint256", internalType: "uint256" }],
    outputs: [],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "send",
    inputs: [
      {
        name: "_sendParam",
        type: "tuple",
        internalType: "struct SendParam",
        components: [
          { name: "dstEid", type: "uint32", internalType: "uint32" },
          { name: "to", type: "bytes32", internalType: "bytes32" },
          {
            name: "amountLD",
            type: "uint256",
            internalType: "uint256",
          },
          {
            name: "minAmountLD",
            type: "uint256",
            internalType: "uint256",
          },
          {
            name: "extraOptions",
            type: "bytes",
            internalType: "bytes",
          },
          { name: "composeMsg", type: "bytes", internalType: "bytes" },
          { name: "oftCmd", type: "bytes", internalType: "bytes" },
        ],
      },
      {
        name: "_fee",
        type: "tuple",
        internalType: "struct MessagingFee",
        components: [
          {
            name: "nativeFee",
            type: "uint256",
            internalType: "uint256",
          },
          {
            name: "lzTokenFee",
            type: "uint256",
            internalType: "uint256",
          },
        ],
      },
      {
        name: "_refundAddress",
        type: "address",
        internalType: "address",
      },
    ],
    outputs: [
      {
        name: "msgReceipt",
        type: "tuple",
        internalType: "struct MessagingReceipt",
        components: [
          { name: "guid", type: "bytes32", internalType: "bytes32" },
          { name: "nonce", type: "uint64", internalType: "uint64" },
          {
            name: "fee",
            type: "tuple",
            internalType: "struct MessagingFee",
            components: [
              {
                name: "nativeFee",
                type: "uint256",
                internalType: "uint256",
              },
              {
                name: "lzTokenFee",
                type: "uint256",
                internalType: "uint256",
              },
            ],
          },
        ],
      },
      {
        name: "oftReceipt",
        type: "tuple",
        internalType: "struct OFTReceipt",
        components: [
          {
            name: "amountSentLD",
            type: "uint256",
            internalType: "uint256",
          },
          {
            name: "amountReceivedLD",
            type: "uint256",
            internalType: "uint256",
          },
        ],
      },
    ],
    stateMutability: "payable",
  },
  {
    type: "function",
    name: "sendWithAuthorization",
    inputs: [
      {
        name: "authorization",
        type: "tuple",
        internalType: "struct IWusdOFTAdapter.OFTSendAuthorization",
        components: [
          {
            name: "authorizer",
            type: "address",
            internalType: "address",
          },
          { name: "sender", type: "address", internalType: "address" },
          {
            name: "sendParams",
            type: "tuple",
            internalType: "struct SendParam",
            components: [
              {
                name: "dstEid",
                type: "uint32",
                internalType: "uint32",
              },
              { name: "to", type: "bytes32", internalType: "bytes32" },
              {
                name: "amountLD",
                type: "uint256",
                internalType: "uint256",
              },
              {
                name: "minAmountLD",
                type: "uint256",
                internalType: "uint256",
              },
              {
                name: "extraOptions",
                type: "bytes",
                internalType: "bytes",
              },
              {
                name: "composeMsg",
                type: "bytes",
                internalType: "bytes",
              },
              { name: "oftCmd", type: "bytes", internalType: "bytes" },
            ],
          },
          {
            name: "deadline",
            type: "uint256",
            internalType: "uint256",
          },
          { name: "nonce", type: "uint256", internalType: "uint256" },
        ],
      },
      { name: "v", type: "uint8", internalType: "uint8" },
      { name: "r", type: "bytes32", internalType: "bytes32" },
      { name: "s", type: "bytes32", internalType: "bytes32" },
      {
        name: "fee",
        type: "tuple",
        internalType: "struct MessagingFee",
        components: [
          {
            name: "nativeFee",
            type: "uint256",
            internalType: "uint256",
          },
          {
            name: "lzTokenFee",
            type: "uint256",
            internalType: "uint256",
          },
        ],
      },
      {
        name: "refundAddress",
        type: "address",
        internalType: "address",
      },
    ],
    outputs: [
      {
        name: "msgReceipt",
        type: "tuple",
        internalType: "struct MessagingReceipt",
        components: [
          { name: "guid", type: "bytes32", internalType: "bytes32" },
          { name: "nonce", type: "uint64", internalType: "uint64" },
          {
            name: "fee",
            type: "tuple",
            internalType: "struct MessagingFee",
            components: [
              {
                name: "nativeFee",
                type: "uint256",
                internalType: "uint256",
              },
              {
                name: "lzTokenFee",
                type: "uint256",
                internalType: "uint256",
              },
            ],
          },
        ],
      },
      {
        name: "oftReceipt",
        type: "tuple",
        internalType: "struct OFTReceipt",
        components: [
          {
            name: "amountSentLD",
            type: "uint256",
            internalType: "uint256",
          },
          {
            name: "amountReceivedLD",
            type: "uint256",
            internalType: "uint256",
          },
        ],
      },
    ],
    stateMutability: "payable",
  },
  {
    type: "function",
    name: "setDelegate",
    inputs: [{ name: "_delegate", type: "address", internalType: "address" }],
    outputs: [],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "setEnforcedOptions",
    inputs: [
      {
        name: "_enforcedOptions",
        type: "tuple[]",
        internalType: "struct EnforcedOptionParam[]",
        components: [
          { name: "eid", type: "uint32", internalType: "uint32" },
          { name: "msgType", type: "uint16", internalType: "uint16" },
          { name: "options", type: "bytes", internalType: "bytes" },
        ],
      },
    ],
    outputs: [],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "setMsgInspector",
    inputs: [
      {
        name: "_msgInspector",
        type: "address",
        internalType: "address",
      },
    ],
    outputs: [],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "setPeer",
    inputs: [
      { name: "_eid", type: "uint32", internalType: "uint32" },
      { name: "_peer", type: "bytes32", internalType: "bytes32" },
    ],
    outputs: [],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "setPreCrime",
    inputs: [{ name: "_preCrime", type: "address", internalType: "address" }],
    outputs: [],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "sharedDecimals",
    inputs: [],
    outputs: [{ name: "", type: "uint8", internalType: "uint8" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "supportsInterface",
    inputs: [{ name: "interfaceId", type: "bytes4", internalType: "bytes4" }],
    outputs: [{ name: "", type: "bool", internalType: "bool" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "token",
    inputs: [],
    outputs: [{ name: "", type: "address", internalType: "address" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "transferOwnership",
    inputs: [{ name: "newOwner", type: "address", internalType: "address" }],
    outputs: [],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "unpause",
    inputs: [],
    outputs: [],
    stateMutability: "nonpayable",
  },
  {
    type: "event",
    name: "AccessRegistryUpdated",
    inputs: [
      {
        name: "caller",
        type: "address",
        indexed: true,
        internalType: "address",
      },
      {
        name: "oldAccessRegistry",
        type: "address",
        indexed: true,
        internalType: "address",
      },
      {
        name: "newAccessRegistry",
        type: "address",
        indexed: true,
        internalType: "address",
      },
    ],
    anonymous: false,
  },
  {
    type: "event",
    name: "EIP712DomainChanged",
    inputs: [],
    anonymous: false,
  },
  {
    type: "event",
    name: "EmbargoLock",
    inputs: [
      {
        name: "recipient",
        type: "address",
        indexed: true,
        internalType: "address",
      },
      {
        name: "bError",
        type: "bytes",
        indexed: false,
        internalType: "bytes",
      },
      {
        name: "amount",
        type: "uint256",
        indexed: false,
        internalType: "uint256",
      },
    ],
    anonymous: false,
  },
  {
    type: "event",
    name: "EmbargoRelease",
    inputs: [
      {
        name: "caller",
        type: "address",
        indexed: true,
        internalType: "address",
      },
      {
        name: "embargoedAccount",
        type: "address",
        indexed: true,
        internalType: "address",
      },
      {
        name: "_to",
        type: "address",
        indexed: true,
        internalType: "address",
      },
      {
        name: "amount",
        type: "uint256",
        indexed: false,
        internalType: "uint256",
      },
    ],
    anonymous: false,
  },
  {
    type: "event",
    name: "EnforcedOptionSet",
    inputs: [
      {
        name: "_enforcedOptions",
        type: "tuple[]",
        indexed: false,
        internalType: "struct EnforcedOptionParam[]",
        components: [
          { name: "eid", type: "uint32", internalType: "uint32" },
          { name: "msgType", type: "uint16", internalType: "uint16" },
          { name: "options", type: "bytes", internalType: "bytes" },
        ],
      },
    ],
    anonymous: false,
  },
  {
    type: "event",
    name: "GasTokenSalvaged",
    inputs: [
      {
        name: "caller",
        type: "address",
        indexed: true,
        internalType: "address",
      },
      {
        name: "amount",
        type: "uint256",
        indexed: false,
        internalType: "uint256",
      },
    ],
    anonymous: false,
  },
  {
    type: "event",
    name: "MsgInspectorSet",
    inputs: [
      {
        name: "inspector",
        type: "address",
        indexed: false,
        internalType: "address",
      },
    ],
    anonymous: false,
  },
  {
    type: "event",
    name: "OFTReceived",
    inputs: [
      {
        name: "guid",
        type: "bytes32",
        indexed: true,
        internalType: "bytes32",
      },
      {
        name: "srcEid",
        type: "uint32",
        indexed: false,
        internalType: "uint32",
      },
      {
        name: "toAddress",
        type: "address",
        indexed: true,
        internalType: "address",
      },
      {
        name: "amountReceivedLD",
        type: "uint256",
        indexed: false,
        internalType: "uint256",
      },
    ],
    anonymous: false,
  },
  {
    type: "event",
    name: "OFTSent",
    inputs: [
      {
        name: "guid",
        type: "bytes32",
        indexed: true,
        internalType: "bytes32",
      },
      {
        name: "dstEid",
        type: "uint32",
        indexed: false,
        internalType: "uint32",
      },
      {
        name: "fromAddress",
        type: "address",
        indexed: true,
        internalType: "address",
      },
      {
        name: "amountSentLD",
        type: "uint256",
        indexed: false,
        internalType: "uint256",
      },
      {
        name: "amountReceivedLD",
        type: "uint256",
        indexed: false,
        internalType: "uint256",
      },
    ],
    anonymous: false,
  },
  {
    type: "event",
    name: "OwnershipTransferred",
    inputs: [
      {
        name: "previousOwner",
        type: "address",
        indexed: true,
        internalType: "address",
      },
      {
        name: "newOwner",
        type: "address",
        indexed: true,
        internalType: "address",
      },
    ],
    anonymous: false,
  },
  {
    type: "event",
    name: "Paused",
    inputs: [
      {
        name: "account",
        type: "address",
        indexed: false,
        internalType: "address",
      },
    ],
    anonymous: false,
  },
  {
    type: "event",
    name: "PeerSet",
    inputs: [
      {
        name: "eid",
        type: "uint32",
        indexed: false,
        internalType: "uint32",
      },
      {
        name: "peer",
        type: "bytes32",
        indexed: false,
        internalType: "bytes32",
      },
    ],
    anonymous: false,
  },
  {
    type: "event",
    name: "PreCrimeSet",
    inputs: [
      {
        name: "preCrimeAddress",
        type: "address",
        indexed: false,
        internalType: "address",
      },
    ],
    anonymous: false,
  },
  {
    type: "event",
    name: "RoleAdminChanged",
    inputs: [
      {
        name: "role",
        type: "bytes32",
        indexed: true,
        internalType: "bytes32",
      },
      {
        name: "previousAdminRole",
        type: "bytes32",
        indexed: true,
        internalType: "bytes32",
      },
      {
        name: "newAdminRole",
        type: "bytes32",
        indexed: true,
        internalType: "bytes32",
      },
    ],
    anonymous: false,
  },
  {
    type: "event",
    name: "RoleGranted",
    inputs: [
      {
        name: "role",
        type: "bytes32",
        indexed: true,
        internalType: "bytes32",
      },
      {
        name: "account",
        type: "address",
        indexed: true,
        internalType: "address",
      },
      {
        name: "sender",
        type: "address",
        indexed: true,
        internalType: "address",
      },
    ],
    anonymous: false,
  },
  {
    type: "event",
    name: "RoleRevoked",
    inputs: [
      {
        name: "role",
        type: "bytes32",
        indexed: true,
        internalType: "bytes32",
      },
      {
        name: "account",
        type: "address",
        indexed: true,
        internalType: "address",
      },
      {
        name: "sender",
        type: "address",
        indexed: true,
        internalType: "address",
      },
    ],
    anonymous: false,
  },
  {
    type: "event",
    name: "TokenSalvaged",
    inputs: [
      {
        name: "caller",
        type: "address",
        indexed: true,
        internalType: "address",
      },
      {
        name: "token",
        type: "address",
        indexed: true,
        internalType: "address",
      },
      {
        name: "amount",
        type: "uint256",
        indexed: false,
        internalType: "uint256",
      },
    ],
    anonymous: false,
  },
  {
    type: "event",
    name: "Unpaused",
    inputs: [
      {
        name: "account",
        type: "address",
        indexed: false,
        internalType: "address",
      },
    ],
    anonymous: false,
  },
  { type: "error", name: "AccessControlBadConfirmation", inputs: [] },
  {
    type: "error",
    name: "AccessControlUnauthorizedAccount",
    inputs: [
      { name: "account", type: "address", internalType: "address" },
      { name: "neededRole", type: "bytes32", internalType: "bytes32" },
    ],
  },
  {
    type: "error",
    name: "AccountUnauthorized",
    inputs: [{ name: "account", type: "address", internalType: "address" }],
  },
  { type: "error", name: "DefaultAdminError", inputs: [] },
  { type: "error", name: "ECDSAInvalidSignature", inputs: [] },
  {
    type: "error",
    name: "ECDSAInvalidSignatureLength",
    inputs: [{ name: "length", type: "uint256", internalType: "uint256" }],
  },
  {
    type: "error",
    name: "ECDSAInvalidSignatureS",
    inputs: [{ name: "s", type: "bytes32", internalType: "bytes32" }],
  },
  { type: "error", name: "EnforcedPause", inputs: [] },
  { type: "error", name: "ExpectedPause", inputs: [] },
  { type: "error", name: "ExpiredAuthorization", inputs: [] },
  {
    type: "error",
    name: "InvalidAccountNonce",
    inputs: [
      { name: "account", type: "address", internalType: "address" },
      { name: "currentNonce", type: "uint256", internalType: "uint256" },
    ],
  },
  { type: "error", name: "InvalidDelegate", inputs: [] },
  { type: "error", name: "InvalidEndpointCall", inputs: [] },
  { type: "error", name: "InvalidImplementation", inputs: [] },
  { type: "error", name: "InvalidLocalDecimals", inputs: [] },
  {
    type: "error",
    name: "InvalidOptions",
    inputs: [{ name: "options", type: "bytes", internalType: "bytes" }],
  },
  { type: "error", name: "InvalidShortString", inputs: [] },
  { type: "error", name: "LzTokenUnavailable", inputs: [] },
  { type: "error", name: "NoBalance", inputs: [] },
  {
    type: "error",
    name: "NoPeer",
    inputs: [{ name: "eid", type: "uint32", internalType: "uint32" }],
  },
  {
    type: "error",
    name: "NotEnoughNative",
    inputs: [{ name: "msgValue", type: "uint256", internalType: "uint256" }],
  },
  {
    type: "error",
    name: "OnlyEndpoint",
    inputs: [{ name: "addr", type: "address", internalType: "address" }],
  },
  {
    type: "error",
    name: "OnlyPeer",
    inputs: [
      { name: "eid", type: "uint32", internalType: "uint32" },
      { name: "sender", type: "bytes32", internalType: "bytes32" },
    ],
  },
  { type: "error", name: "OnlySelf", inputs: [] },
  {
    type: "error",
    name: "OwnableInvalidOwner",
    inputs: [{ name: "owner", type: "address", internalType: "address" }],
  },
  {
    type: "error",
    name: "OwnableUnauthorizedAccount",
    inputs: [{ name: "account", type: "address", internalType: "address" }],
  },
  {
    type: "error",
    name: "SafeERC20FailedOperation",
    inputs: [{ name: "token", type: "address", internalType: "address" }],
  },
  { type: "error", name: "SalvageGasFailed", inputs: [] },
  {
    type: "error",
    name: "SimulationResult",
    inputs: [{ name: "result", type: "bytes", internalType: "bytes" }],
  },
  {
    type: "error",
    name: "SlippageExceeded",
    inputs: [
      { name: "amountLD", type: "uint256", internalType: "uint256" },
      { name: "minAmountLD", type: "uint256", internalType: "uint256" },
    ],
  },
  {
    type: "error",
    name: "StringTooLong",
    inputs: [{ name: "str", type: "string", internalType: "string" }],
  },
  { type: "error", name: "UnauthorizedTokenManagement", inputs: [] },
  { type: "error", name: "ZeroAmount", inputs: [] },
] as const;
