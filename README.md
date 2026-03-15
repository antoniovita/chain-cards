forge script script/DeployAnvil.s.sol:DeployAnvil --rpc-url http://127.0.0.1:8545 --broadcast -vv


forge script script/FundAnvil.s.sol:FundAnvil --rpc-url http://127.0.0.1:8545 --broadcast -vv


forge script script/DeployMonadTestnet.s.sol:DeployMonadTestnet --rpc-url "$RPC_URL_MONAD" --broadcast -vv


forge script script/DeployMonadTestnet.s.sol:DeployMonadTestnet --rpc-url "https://testnet-rpc.monad.xyz" --broadcast -vv