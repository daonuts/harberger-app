package main

import (
    "fmt"
    "log"
    "context"
    "math/big"
    "strings"

    "github.com/ethereum/go-ethereum"
    "github.com/ethereum/go-ethereum/accounts/abi"
    "github.com/ethereum/go-ethereum/common"
    "github.com/ethereum/go-ethereum/crypto"
    "github.com/ethereum/go-ethereum/ethclient"
    "github.com/ethereum/go-ethereum/core/types"

    harberger "../go"
)

func main() {
    // client, err := ethclient.Dial("wss://rinkeby.infura.io/ws")
    client, err := ethclient.Dial("ws://localhost:8545")
    if err != nil {
        log.Fatal(err)
    }

    const HarbergerAddress string = "0x6945b83e886b3ee2cf9c26e9f609f258202bcfc8"

    fmt.Println("we have a connection")

    harbergerAddress := common.HexToAddress(HarbergerAddress)
    // Get contract instances to call methods on them
    harbergerInstance, _ := harberger.NewHarberger(harbergerAddress, client)
    _ = harbergerInstance

    harbergerAbi, _ := abi.JSON(strings.NewReader(string(harberger.HarbergerABI)))

    balanceEventSigHash := crypto.Keccak256Hash([]byte("Balance(uint256,uint256,uint64)"))
    fmt.Println("\nbalanceEventSigHash", balanceEventSigHash.Hex())

    query := ethereum.FilterQuery{
        FromBlock: big.NewInt(0),
        Addresses: []common.Address{harbergerAddress},
    }

    // We can process any events since `FromBlock`
    past, _ := client.FilterLogs(context.Background(), query)

    for _, vLog := range past {

      // The transaction hash can work as a unique transaction identifier (for example, checking whether a transaction been processed/synced)
      fmt.Println("Tx Hash:", vLog.TxHash.Hex())

      switch vLog.Topics[0] {
    	case balanceEventSigHash:
          switch vLog.Address {
          case harbergerAddress:
              fmt.Println("Harberger")
          default:
              fmt.Println("unrecognised event")
          }

          var event harberger.HarbergerBalance
          harbergerAbi.Unpack(&event, "Balance", vLog.Data)
          fmt.Println("\tTokenId:", vLog.Topics[1].Big())
          fmt.Println("\tBalance:", event.Balance)
          fmt.Println("\tExpiration:", event.Expiration)

    	default:
		      fmt.Println("not a monitored event")
    	}
    }

    // As well as process past events we can create an event subscription and monitor for ongoing events
    logs := make(chan types.Log)

    sub, err := client.SubscribeFilterLogs(context.Background(), query, logs)
    if err != nil {
        log.Fatal(err)
    }

    for {
        select {
        case err := <-sub.Err():
            log.Fatal(err)
        case vLog := <-logs:
          switch vLog.Topics[0] {
          case balanceEventSigHash:
              switch vLog.Address {
              case harbergerAddress:
                  fmt.Println("Harberger")
              default:
                  fmt.Println("unrecognised event")
              }
          default:
              fmt.Println("not a monitored event")
          }
        }
    }
}
