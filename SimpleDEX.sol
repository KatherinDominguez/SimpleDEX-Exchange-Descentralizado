// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract SimpleDEX is Ownable {
    IERC20 public tokenA;
    IERC20 public tokenB;
    
    // Reservas del pool de liquidez
    uint256 public reserveA;
    uint256 public reserveB;
    
    // Constante para evitar divisiones por cero
    uint256 private constant MINIMUM_LIQUIDITY = 1000;
    
    // Eventos
    event LiquidityAdded(address indexed provider, uint256 amountA, uint256 amountB);
    event LiquidityRemoved(address indexed provider, uint256 amountA, uint256 amountB);
    event SwapExecuted(address indexed user, address indexed tokenIn, address indexed tokenOut, uint256 amountIn, uint256 amountOut);
    event PriceUpdated(uint256 reserveA, uint256 reserveB);
    
    constructor(address _tokenA, address _tokenB) Ownable(msg.sender) {
        require(_tokenA != address(0), "SimpleDEX: TokenA address cannot be zero");
        require(_tokenB != address(0), "SimpleDEX: TokenB address cannot be zero");
        require(_tokenA != _tokenB, "SimpleDEX: Tokens must be different");
        
        tokenA = IERC20(_tokenA);
        tokenB = IERC20(_tokenB);
    }
    
    // Función para añadir liquidez (solo owner)
    function addLiquidity(uint256 amountA, uint256 amountB) external onlyOwner {
        require(amountA > 0 && amountB > 0, "SimpleDEX: Amounts must be greater than zero");
        
        // Transferir tokens del owner al contrato
        require(tokenA.transferFrom(msg.sender, address(this), amountA), "SimpleDEX: TokenA transfer failed");
        require(tokenB.transferFrom(msg.sender, address(this), amountB), "SimpleDEX: TokenB transfer failed");
        
        // Actualizar reservas
        reserveA += amountA;
        reserveB += amountB;
        
        emit LiquidityAdded(msg.sender, amountA, amountB);
        emit PriceUpdated(reserveA, reserveB);
    }
    
    // Función para intercambiar TokenA por TokenB
    function swapAforB(uint256 amountAIn) external {
        require(amountAIn > 0, "SimpleDEX: Amount must be greater than zero");
        require(reserveA > 0 && reserveB > 0, "SimpleDEX: Insufficient liquidity");
        
        // Calcular cantidad de TokenB a entregar usando la fórmula del producto constante
        // (x + dx)(y - dy) = xy
        // dy = y * dx / (x + dx)
        uint256 amountBOut = (reserveB * amountAIn) / (reserveA + amountAIn);
        
        require(amountBOut > 0, "SimpleDEX: Insufficient output amount");
        require(amountBOut < reserveB, "SimpleDEX: Insufficient liquidity for swap");
        
        // Transferir TokenA del usuario al contrato
        require(tokenA.transferFrom(msg.sender, address(this), amountAIn), "SimpleDEX: TokenA transfer failed");
        
        // Transferir TokenB del contrato al usuario
        require(tokenB.transfer(msg.sender, amountBOut), "SimpleDEX: TokenB transfer failed");
        
        // Actualizar reservas
        reserveA += amountAIn;
        reserveB -= amountBOut;
        
        emit SwapExecuted(msg.sender, address(tokenA), address(tokenB), amountAIn, amountBOut);
        emit PriceUpdated(reserveA, reserveB);
    }
    
    // Función para intercambiar TokenB por TokenA
    function swapBforA(uint256 amountBIn) external {
        require(amountBIn > 0, "SimpleDEX: Amount must be greater than zero");
        require(reserveA > 0 && reserveB > 0, "SimpleDEX: Insufficient liquidity");
        
        // Calcular cantidad de TokenA a entregar usando la fórmula del producto constante
        uint256 amountAOut = (reserveA * amountBIn) / (reserveB + amountBIn);
        
        require(amountAOut > 0, "SimpleDEX: Insufficient output amount");
        require(amountAOut < reserveA, "SimpleDEX: Insufficient liquidity for swap");
        
        // Transferir TokenB del usuario al contrato
        require(tokenB.transferFrom(msg.sender, address(this), amountBIn), "SimpleDEX: TokenB transfer failed");
        
        // Transferir TokenA del contrato al usuario
        require(tokenA.transfer(msg.sender, amountAOut), "SimpleDEX: TokenA transfer failed");
        
        // Actualizar reservas
        reserveB += amountBIn;
        reserveA -= amountAOut;
        
        emit SwapExecuted(msg.sender, address(tokenB), address(tokenA), amountBIn, amountAOut);
        emit PriceUpdated(reserveA, reserveB);
    }
    
    // Función para retirar liquidez (solo owner)
    function removeLiquidity(uint256 amountA, uint256 amountB) external onlyOwner {
        require(amountA > 0 && amountB > 0, "SimpleDEX: Amounts must be greater than zero");
        require(amountA <= reserveA && amountB <= reserveB, "SimpleDEX: Insufficient liquidity");
        
        // Transferir tokens del contrato al owner
        require(tokenA.transfer(msg.sender, amountA), "SimpleDEX: TokenA transfer failed");
        require(tokenB.transfer(msg.sender, amountB), "SimpleDEX: TokenB transfer failed");
        
        // Actualizar reservas
        reserveA -= amountA;
        reserveB -= amountB;
        
        emit LiquidityRemoved(msg.sender, amountA, amountB);
        emit PriceUpdated(reserveA, reserveB);
    }
    
    // Función para obtener el precio de un token en términos del otro
    function getPrice(address _token) external view returns (uint256) {
        require(_token == address(tokenA) || _token == address(tokenB), "SimpleDEX: Invalid token address");
        require(reserveA > 0 && reserveB > 0, "SimpleDEX: No liquidity available");
        
        if (_token == address(tokenA)) {
            // Precio de TokenA en términos de TokenB
            return (reserveB * 1e18) / reserveA;
        } else {
            // Precio de TokenB en términos de TokenA
            return (reserveA * 1e18) / reserveB;
        }
    }
    
    // Funciones auxiliares para consultar información del pool
    function getReserves() external view returns (uint256, uint256) {
        return (reserveA, reserveB);
    }
    
    function getTokenAddresses() external view returns (address, address) {
        return (address(tokenA), address(tokenB));
    }
    
    // Función para calcular el output de un swap sin ejecutarlo
    function getAmountOut(uint256 amountIn, address tokenIn) external view returns (uint256) {
        require(tokenIn == address(tokenA) || tokenIn == address(tokenB), "SimpleDEX: Invalid token address");
        require(amountIn > 0, "SimpleDEX: Amount must be greater than zero");
        require(reserveA > 0 && reserveB > 0, "SimpleDEX: Insufficient liquidity");
        
        if (tokenIn == address(tokenA)) {
            return (reserveB * amountIn) / (reserveA + amountIn);
        } else {
            return (reserveA * amountIn) / (reserveB + amountIn);
        }
    }
    
    // Función de emergencia para retirar tokens (solo owner)
    function emergencyWithdraw(address token, uint256 amount) external onlyOwner {
        require(token != address(0), "SimpleDEX: Invalid token address");
        IERC20(token).transfer(msg.sender, amount);
    }
}