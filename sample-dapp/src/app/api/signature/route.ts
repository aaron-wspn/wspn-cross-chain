import { NextResponse } from "next/server";
import {
  BasePath,
  CreateTransactionResponse,
  Fireblocks,
  FireblocksResponse,
  TransactionOperation,
  TransactionRequest,
  TransactionResponse,
  TransactionStateEnum,
  TransferPeerPathType,
} from "@fireblocks/ts-sdk";
import { TypedDataDomain, TypedDataToPrimitiveTypes } from "abitype";
import { Address, padHex } from "viem";
import { chainIdToFireblocksAssetId } from "../../config/fireblocksChainIdMap";
import { AuthRequest } from "../../page";
import { EndpointId } from "@layerzerolabs/lz-definitions";
import { chainIdToOmniPoint } from "../../config/omniPointMap";
import { config } from "../wagmiConfig";
import { wusdOftAdapterAbi } from "../../abi/WusdOFTAdapter";
import { readContract } from "viem/actions";

// Initialize Fireblocks SDK with API key from env vars
// const fireblocks = new FireblocksSDK(
//   process.env.FIREBLOCKS_API_SECRET_KEY || "",
//   process.env.FIREBLOCKS_API_KEY || ""
// );
// Initialize a Fireblocks API instance with local variables
const fireblocks = new Fireblocks({
  apiKey: process.env.FIREBLOCKS_API_KEY || "",
  basePath: BasePath.US, // or assign directly e.g. "https://sandbox-api.fireblocks.io/v1";
  secretKey: process.env.FIREBLOCKS_API_SECRET_KEY || "",
});

export type SignedTypedMessageType =
  | "EIP191"
  | "EIP712"
  | "TIP191"
  | "BTC_MESSAGE";
export type RawMessage = {
  content: object;
  type: SignedTypedMessageType;
};

export const oftSendAuthorizationEIP712Types = {
  EIP712Domain: [
    { name: "name", type: "string" },
    { name: "version", type: "string" },
    { name: "chainId", type: "uint256" },
    { name: "verifyingContract", type: "address" },
  ],
  OFTSendAuthorization: [
    { name: "authorizer", type: "address" },
    { name: "sender", type: "address" },
    { name: "sendParams", type: "SendParam" },
    { name: "deadline", type: "uint256" },
    { name: "nonce", type: "uint256" },
  ],
  SendParam: [
    { name: "dstEid", type: "uint32" },
    { name: "to", type: "bytes32" },
    { name: "amountLD", type: "uint256" },
    { name: "minAmountLD", type: "uint256" },
    { name: "extraOptions", type: "bytes" },
    { name: "composeMsg", type: "bytes" },
    { name: "oftCmd", type: "bytes" },
  ],
} as const;

export type OFTSendAuthorization = TypedDataToPrimitiveTypes<
  typeof oftSendAuthorizationEIP712Types
>["OFTSendAuthorization"];

export type SendParam = TypedDataToPrimitiveTypes<
  typeof oftSendAuthorizationEIP712Types
>["SendParam"];
export interface RawMessageData {
  messages: RawMessage[];
}

const createEip712Message = (
  from: Address,
  to: `0x${string}`,
  amount: bigint,
  deadline: number,
  authorizer: Address,
  chainId: number,
  contractAddress: Address,
  dstLzEndpointId: EndpointId,
  nonce: number,
  options: `0x${string}`
) => {
  const domain: TypedDataDomain = {
    name: "WusdOFTAdapter",
    version: "1",
    chainId,
    verifyingContract: contractAddress,
  };

  const sendParams: SendParam = {
    dstEid: dstLzEndpointId,
    to: padHex(to, { size: 32 }), // Pad to 32 bytes using viem
    amountLD: amount,
    minAmountLD: amount, // Using same amount as minimum
    extraOptions: options,
    composeMsg: "0x",
    oftCmd: "0x",
  };

  const message: OFTSendAuthorization = {
    authorizer,
    sender: from,
    sendParams,
    deadline: BigInt(deadline),
    nonce: BigInt(nonce),
  };

  return {
    types: oftSendAuthorizationEIP712Types,
    primaryType: "OFTSendAuthorization",
    domain,
    message,
  };
};

/**
 * Fireblocks uses standard ECDSA recovery id (0 or 1).
 * Ethereum uses 27 or 28, but EIP-155 which informs EIP-712, specifies v = (0 or 1) + chainId * 2 + 35.
 * However the Openzeppelin ECDSA in use does not support EIP-155 recovery ids (uint8 type). Therefore,
 * this function converts the recovery id to an Ethereum recovery id.
 * @param v - The ECDSA recovery id (returned by Fireblocks)
 * @param chainId - The chain id of the transaction
 * @returns The EIP-155 recovery id
 */
const postProcessFireblocksRecoveryId = (
  v: number,
  chainId?: number // Do not use!
): number => {
  return v! + 27;
};

const createSignTypedMessageTransaction = async (
  assetId: string,
  typedMessage: object
) => {
  // Convert BigInt values to strings in the typed message
  const serializedMessage = JSON.parse(
    JSON.stringify(typedMessage, (_, value) =>
      typeof value === "bigint" ? value.toString() : value
    )
  );

  const rawMessage: RawMessage = {
    content: serializedMessage,
    type: "EIP712",
  };
  const rawMessagesDataObj: RawMessageData = {
    messages: [rawMessage],
  };

  let payload: TransactionRequest = {
    operation: TransactionOperation.TypedMessage,
    assetId,
    source: {
      type: TransferPeerPathType.VaultAccount,
      id: process.env.FIREBLOCKS_AUTHORIZER_VAULT_ID || "",
    },
    extraParameters: {
      rawMessageData: rawMessagesDataObj,
      note: "Bridge Authorization Signature",
    },
  };
  console.log(JSON.stringify(payload, null, 2));

  const transactionResponse = await fireblocks.transactions.createTransaction({
    transactionRequest: payload,
  });

  return transactionResponse.data;
};

const pollTxResolution = async (txId: string): Promise<TransactionResponse> => {
  try {
    let response: FireblocksResponse<TransactionResponse> =
      await fireblocks.transactions.getTransaction({ txId });
    let tx: TransactionResponse = response.data;
    let messageToConsole: string = `Transaction ${tx.id} is currently at status - ${tx.status}`;

    console.log(messageToConsole);
    while (tx.status !== TransactionStateEnum.Completed) {
      await new Promise((resolve) => setTimeout(resolve, 3000));

      response = await fireblocks.transactions.getTransaction({ txId });
      tx = response.data;

      switch (tx.status) {
        case TransactionStateEnum.Blocked:
        case TransactionStateEnum.Cancelled:
        case TransactionStateEnum.Failed:
        case TransactionStateEnum.Rejected:
          throw new Error(
            `Signing request failed/blocked/cancelled: Transaction: ${tx.id} status is ${tx.status}`
          );
        default:
          console.log(messageToConsole);
          break;
      }
    }
    while (tx.status !== TransactionStateEnum.Completed);
    return tx;
  } catch (error) {
    throw error;
  }
};

// Type guard to ensure chain is one of our supported chains
function isConfiguredChain(
  chainId: number
): chainId is (typeof config.chains)[number]["id"] {
  return config.chains.some((chain) => chain.id === chainId);
}

// Simplified getPublicClient that creates a viem client directly
const getPublicClient = (chainId: number) => {
  if (!isConfiguredChain(chainId)) {
    throw new Error(`Chain ${chainId} not configured`);
  }
  return config.getClient({ chainId });
};

// The getNonce function remains the same
const getNonce = async (
  chainId: number,
  authorizer: Address
): Promise<number> => {
  const client = getPublicClient(chainId);
  const adapterAddress = chainIdToOmniPoint[chainId].address as `0x${string}`;

  const nonce = await readContract(client, {
    address: adapterAddress,
    abi: wusdOftAdapterAbi,
    functionName: "nonces",
    args: [authorizer],
  });
  console.log("Nonce:", nonce);
  return Number(nonce);
};

export async function POST(req: Request) {
  try {
    const body = await req.json();
    const {
      from,
      to,
      amount,
      adapterAddress,
      srcChainId,
      dstChainId,
      options,
    }: AuthRequest = body;

    // Add authorization details
    const deadline = Math.floor(Date.now() / 1000) + 3600; // 1 hour from now
    const authorizerAddress = (process.env.FIREBLOCKS_AUTHORIZER_ADDRESS ||
      "0x") as `0x${string}`;
    const chainId = srcChainId;

    // In real implementation, you would fetch this from the contract
    const nonce = await getNonce(chainId, authorizerAddress);

    const eip712message = createEip712Message(
      from,
      to,
      BigInt(amount),
      deadline,
      authorizerAddress!,
      chainId,
      adapterAddress,
      chainIdToOmniPoint[dstChainId].eid,
      nonce,
      options
    );
    // console.log(
    //   "EIP712 Message:",
    //   JSON.stringify(
    //     eip712message,
    //     (_, value) => (typeof value === "bigint" ? value.toString() : value),
    //     2
    //   )
    // );

    const createTxRes: CreateTransactionResponse =
      await createSignTypedMessageTransaction(
        chainIdToFireblocksAssetId[dstChainId],
        eip712message
      );

    const txId = createTxRes.id;
    if (!txId) {
      throw new Error("Transaction ID is undefined.");
    }
    const txInfo = await pollTxResolution(txId);

    console.log("Transaction Response:", JSON.stringify(txInfo, null, 2));

    return NextResponse.json({
      success: true,
      data: {
        payload: JSON.parse(
          JSON.stringify(
            eip712message.message,
            (_, value) =>
              typeof value === "bigint" ? value.toString() : value,
            2
          )
        ),
        signature: {
          r: `0x${txInfo.signedMessages![0]?.signature?.r}`,
          s: `0x${txInfo.signedMessages![0]?.signature?.s}`,
          v: postProcessFireblocksRecoveryId(
            txInfo.signedMessages![0]?.signature?.v!
          ),
        },
        // In real implementation, you would:
        // 1. Send transactionPayload to Fireblocks
        // 2. Get transaction ID
        // 3. Return transaction ID for polling
      },
    });
  } catch (error) {
    console.error("Signature request failed:", error);
    return NextResponse.json(
      { success: false, error: "Failed to get signature" },
      { status: 500 }
    );
  }
}
