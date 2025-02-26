"use client";

import { ConnectButton } from "@rainbow-me/rainbowkit";
import { useAccount, useConfig, useReadContracts, useWriteContract } from "wagmi";
import styles from "../styles/Home.module.css";
import { useState } from "react";
import { getTokenAddress } from "./config/tokens";
import { Address, erc20Abi, formatUnits, parseEther } from "viem";
import { Options } from "@layerzerolabs/lz-v2-utilities";
import { AbiParametersToPrimitiveTypes, ExtractAbiFunction } from "abitype";
import { wusdOftAdapterAbi } from "./abi/WusdOFTAdapter";
import { OFTSendAuthorization, SendParam } from "./api/signature/route";
import { readContract, simulateContract } from "viem/actions";
import { chainIdToOmniPoint } from "./config/omniPointMap";

export interface AuthRequest {
  from: Address;
  to: Address;
  amount: string; // stringified bigint
  adapterAddress: Address;
  srcChainId: number;
  dstChainId: number;
  options: `0x${string}`;
}

interface ApiResponse {
  success: boolean;
  data?: {
    payload: OFTSendAuthorization;
    signature?: {
      r: `0x${string}`;
      s: `0x${string}`;
      v: number;
    };
  };
  error?: string;
}

type SendWithAuthorizationAbiFunctionInputParams = ExtractAbiFunction<
  typeof wusdOftAdapterAbi,
  "sendWithAuthorization"
>["inputs"];
type SendWithAuthorizationInput = AbiParametersToPrimitiveTypes<
  SendWithAuthorizationAbiFunctionInputParams,
  "inputs"
>;

export default function Home() {
  const { address, chain } = useAccount();
  const config = useConfig();
  const tokenConfigKey = "WUSD";
  const [amount, setAmount] = useState("");
  // Initialize with first available chain that's different from current
  const [selectedChain, setSelectedChain] = useState(() => {
    const availableChains = config.chains.filter((c) => c.id !== chain?.id);
    return availableChains[0];
  });
  // Get balances from both chains
  const chain1Result = useReadContracts({
    allowFailure: false, // WARNING: Change back to false when ready
    contracts: [
      {
        address: getTokenAddress(chain?.id!, tokenConfigKey),
        abi: erc20Abi,
        functionName: "balanceOf",
        args: [address!],
      },
      {
        address: getTokenAddress(chain?.id!, tokenConfigKey),
        abi: erc20Abi,
        functionName: "decimals",
      },
      {
        address: getTokenAddress(chain?.id!, tokenConfigKey),
        abi: erc20Abi,
        functionName: "symbol",
      },
    ],
  });

  const chain2Result = useReadContracts({
    allowFailure: false, // WARNING: Change back to false when ready
    query: {
      placeholderData: [0n, 18, "WUSD"],
    },
    contracts: [
      {
        address: getTokenAddress(selectedChain?.id!, tokenConfigKey),
        abi: erc20Abi,
        functionName: "balanceOf",
        args: [address!],
        chainId: selectedChain?.id,
      },
      {
        address: getTokenAddress(selectedChain?.id!, tokenConfigKey),
        abi: erc20Abi,
        functionName: "decimals",
        chainId: selectedChain?.id,
      },
      {
        address: getTokenAddress(selectedChain?.id!, tokenConfigKey),
        abi: erc20Abi,
        functionName: "symbol",
        chainId: selectedChain?.id,
      },
    ],
  });
  

  const { writeContract } = useWriteContract();

  const getMessagingFee = async (sendParam: SendParam) => {
    return readContract(config.getClient(), {
      abi: wusdOftAdapterAbi,
      address: chainIdToOmniPoint[chain?.id!].address as `0x${string}`,
      functionName: "quoteSend",
      args: [sendParam, false],
    });
  };
  const formatTokenBalance = (balance: bigint, decimals: number) => {
    return formatUnits(balance, decimals);
  };

  const handleBridge = async (e: React.FormEvent) => {
    e.preventDefault();
    // Implement bridge logic here
    console.log(
      "Bridging",
      amount,
      "tokens from",
      chain?.name,
      "to",
      selectedChain.name
    );
    const { request } = await simulateContract(config.getClient(), {
      account: address!, // signer
      abi: wusdOftAdapterAbi,
      address: chainIdToOmniPoint[chain?.id!].address as `0x${string}`,
      functionName: 'sendWithAuthorization',
      args: [callData![0], callData![1], callData![2], callData![3], callData![4], callData![5]],
      value: callData![4].nativeFee
    })
    const txHash = await writeContract(request);
    console.log("Transaction hash:", txHash);
  };

  // Get available destination chains (excluding current chain)
  const destinationChains = config.chains.filter((c) => c.id !== chain?.id);

  const [isRequestingAuth, setIsRequestingAuth] = useState(false);
  const [authRequest, setAuthRequest] = useState<AuthRequest | null>(null);
  const [apiResponse, setApiResponse] = useState<ApiResponse | null>(null);
  const [isPolling, setIsPolling] = useState(false);
  const [callData, setCallData] = useState<SendWithAuthorizationInput | null>(
    null
  );

  const requestAuthorization = async () => {
    if (!address || !selectedChain || !amount) return;

    if (!chain) throw new Error("No chain selection in wallet");

    const options = Options.newOptions()
      .addExecutorLzReceiveOption(300000, 0)
      .toHex()
      .toString() as `0x${string}`;
    const authRequest: AuthRequest = {
      from: address,
      to: address,
      amount: parseEther(amount).toString(10),
      adapterAddress: chainIdToOmniPoint[chain?.id!].address as `0x${string}`,
      srcChainId: chain.id!,
      dstChainId: selectedChain.id,
      options: options,
    };
    setApiResponse(null);
    setIsRequestingAuth(true);
    setAuthRequest(authRequest);
    setIsPolling(true);

    try {
      const response = await fetch("/api/signature", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify(authRequest),
      });

      const sigApiResponse = (await response.json()) as ApiResponse;
      setApiResponse(sigApiResponse);
      setAuthRequest(null);
      const messagingFee = await getMessagingFee(
        sigApiResponse.data?.payload.sendParams!
      );

      // Start polling for signature (in real implementation)
      // For now, we are doing it inside the backend call
      // which results in a long HTTP request

      setIsPolling(false);
      // Prepare call data for the bridge transaction
      setCallData([
        {
          authorizer: sigApiResponse.data?.payload.authorizer!,
          sender: address,
          sendParams: {
            dstEid: sigApiResponse.data?.payload.sendParams.dstEid!,
            to: sigApiResponse.data?.payload.sendParams.to!,
            amountLD: parseEther(amount),
            minAmountLD: parseEther(amount),
            extraOptions: options,
            composeMsg: "0x",
            oftCmd: "0x",
          },
          deadline: sigApiResponse.data?.payload.deadline!,
          nonce: sigApiResponse.data?.payload.nonce!,
        },
        sigApiResponse.data?.signature?.v!,
        sigApiResponse.data?.signature?.r!,
        sigApiResponse.data?.signature?.s!,
        messagingFee,
        address,
      ]);
    } catch (error) {
      console.error("Authorization request failed:", error);
      setApiResponse({
        success: false,
        error: "Failed to request authorization",
      });
    } finally {
      setIsRequestingAuth(false);
    }
  };

  const resetCallData = () => {
    setCallData(null);
    setAuthRequest(null);
    setApiResponse(null);
  };

  return (
    <div className={styles.container}>
      <main className={styles.main}>
        <h1 className={styles.title}>Token Bridge</h1>

        <div className={styles.bridgeContainer}>
          <ConnectButton />

          {address && (
            <div className={styles.bridgeCard}>
              <div className={styles.networkInfo}>
                <div className={styles.networkBox}>
                  <h3>From</h3>
                  <p className={styles.current}>
                    {chain?.name || "Not Connected"}
                  </p>
                  {chain1Result.data && (
                    <div className={styles.balanceInfo}>
                      <p className={styles.balance}>
                        Balance:{" "}
                        {formatTokenBalance(
                          chain1Result.data[0],
                          chain1Result.data[1]
                        )}{" "}
                        {chain1Result.data[2]}
                      </p>
                      <button
                        type="button"
                        className={styles.maxButton}
                        onClick={() =>
                          setAmount(
                            formatTokenBalance(
                              chain1Result.data[0],
                              chain1Result.data[1]
                            )
                          )
                        }
                      >
                        MAX
                      </button>
                    </div>
                  )}
                </div>
                <div className={styles.arrow}>→</div>
                <div className={styles.networkBox}>
                  <h3>To</h3>
                  <select
                    value={selectedChain?.id}
                    onChange={(e) => {
                      const chain = config.chains.find(
                        (c) => c.id === Number(e.target.value)
                      );
                      if (chain) {
                        setSelectedChain(chain);
                        setAmount("");
                        console.log("Selected chain:", chain);
                      }
                    }}
                    className={styles.select}
                  >
                    {destinationChains.map((chain) => (
                      <option key={chain.id} value={chain.id}>
                        {chain.name}
                      </option>
                    ))}
                  </select>
                  <div className={styles.balanceInfo}>
                    <p className={styles.balance}>
                      Balance: {chain2Result.isPlaceholderData && "Loading..."}
                      {chain2Result.data &&
                        !chain2Result.isFetching &&
                        formatTokenBalance(
                          chain2Result.data[0],
                          chain2Result.data[1]
                        ) +
                          " " +
                          chain2Result.data[2]}
                      {chain2Result.isError && "Error"}
                    </p>
                  </div>
                </div>
              </div>

              <form onSubmit={handleBridge} className={styles.bridgeForm}>
                <div className={styles.inputGroup}>
                  <input
                    type="number"
                    placeholder="Amount"
                    value={amount}
                    onChange={(e) => setAmount(e.target.value)}
                    className={styles.input}
                    step="any"
                    min="0"
                    required
                  />
                  {chain1Result.data ? (
                    <span className={styles.tokenSymbol}>
                      {chain1Result.data[2]}
                    </span>
                  ) : (
                    <span className={styles.tokenSymbol}>TOKEN</span>
                  )}
                </div>

                <button
                  type="button"
                  className={styles.authButton}
                  disabled={!selectedChain || !amount || isRequestingAuth}
                  onClick={requestAuthorization}
                >
                  {isPolling ? (
                    <div className={styles.loadingSpinner}>
                      Awaiting Authorization...
                    </div>
                  ) : (
                    "Request Authorization"
                  )}
                </button>

                {authRequest && (
                  <div className={styles.responseCard}>
                    <h3>Authorization Request</h3>
                    <pre>{JSON.stringify(authRequest, null, 2)}</pre>
                  </div>
                )}

                {apiResponse && (
                  <div className={styles.responseCard}>
                    <h3>Authorization Response</h3>
                    <pre>{JSON.stringify(apiResponse, null, 2)}</pre>
                  </div>
                )}

                {callData && (
                  <div className={styles.callDataCard}>
                    <h3>Transaction Details</h3>
                    <div>
                      <p>Destination Chain: {selectedChain.name}</p>
                      <p>
                        Amount: {amount} {chain1Result.data?.[2]}
                      </p>
                      <p>Recipient: {callData[0].sendParams.to.replace(/^0x0+/, '0x0...0')}</p>
                      <p>
                        Messaging Fee: {formatUnits(callData[4].nativeFee, 18)}{" "}
                        {chain?.nativeCurrency.symbol}
                      </p>
                    </div>
                  </div>
                )}

                <button
                  type="submit"
                  className={styles.bridgeButton}
                  disabled={!selectedChain || !amount || !callData || isPolling}
                >
                  Bridge Tokens
                </button>
              </form>
            </div>
          )}

          {!address && (
            <p className={styles.description}>
              Connect your wallet to start bridging tokens
            </p>
          )}
        </div>
      </main>

      <footer className={styles.footer}>
        <a href="https://rainbow.me" rel="noopener noreferrer" target="_blank">
          Made with ❤️ by your frens at 🌈
        </a>
      </footer>
    </div>
  );
}
