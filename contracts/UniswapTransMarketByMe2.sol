// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

//LP Token
interface IUniswapV2Pair {
    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);

    function balanceOf(address owner) external view returns (uint);

    function allowance(
        address owner,
        address spender
    ) external view returns (uint);

    function approve(address spender, uint value) external returns (bool);

    function transfer(address to, uint value) external returns (bool);

    function transferFrom(
        address from,
        address to,
        uint value
    ) external returns (bool);

    function DOMAIN_SEPARATOR() external view returns (bytes32);

    function PERMIT_TYPEHASH() external pure returns (bytes32);

    function nonces(address owner) external view returns (uint);

    function permit(
        address owner,
        address spender,
        uint value,
        uint deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    event Mint(address indexed sender, uint amount0, uint amount1);
    event Burn(
        address indexed sender,
        uint amount0,
        uint amount1,
        address indexed to
    );
    event Swap(
        address indexed sender,
        uint amount0In,
        uint amount1In,
        uint amount0Out,
        uint amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);

    function MINIMUM_LIQUIDITY() external pure returns (uint);

    function factory() external view returns (address);

    function token0() external view returns (address);

    function token1() external view returns (address);

    function getReserves()
        external
        view
        returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);

    function price0CumulativeLast() external view returns (uint);

    function price1CumulativeLast() external view returns (uint);

    function kLast() external view returns (uint);

    function mint(address to) external returns (uint liquidity);

    function burn(address to) external returns (uint amount0, uint amount1);

    function swap(
        uint amount0Out,
        uint amount1Out,
        address to,
        bytes calldata data
    ) external;

    function skim(address to) external;

    function sync() external;

    function initialize(address, address) external;
}

//WETH接口
interface IWETH {
    function deposit() external payable;

    function transfer(address to, uint value) external returns (bool);

    function withdraw(uint) external;
}

//ERC20 Token
contract MultERC20 is ERC20, Ownable {
    constructor(
        string memory _name,
        string memory _symbol
    ) ERC20(_name, _symbol) {}

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount * 10 ** 18);
    }
}

contract UniswapV2ByMe is ReentrancyGuard {
    //Görli网络的uinswap官方的路由与工厂合约地址
    address public constant uniswapV2Router =
        0xf164fC0Ec4E93095b804a4795bBe1e041497b92a;
    address public constant uniswapV2Factory =
        0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
    address public constant uniswapV2WETH =
        0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6;
    address internal immutable manager = msg.sender;
    bytes internal constant erc20Bytecode = type(MultERC20).creationCode;
    mapping(address => uint256) public userBlanceOf;
    mapping(address => mapping(address => uint256)) public userBalanceTokenOf;

    struct Token {
        string name;
        string symbol;
    }

    struct TokenParms {
        address token;
        address to;
        uint amountTokenDesired;
        uint amountTokenMin;
        uint deadline;
    }

    event CreateTokenAndTokenB(
        address indexed from,
        address indexed tokenA_,
        address indexed tokenB_
    );

    event CreateTokenAndTokenBPairs(
        address indexed from,
        address indexed token
    );
    
    modifier isHuman() {
        require(msg.sender == tx.origin, "The caller is another contract");
        _;
    }

    receive() external payable {
        require(msg.value > 0, "Ethereum balance must be greater than 0");
        userBlanceOf[msg.sender] = msg.value;
    }

    function create(
        bytes memory bytecode,
        bytes32 salt
    ) internal returns (address token) {
        assembly {
            token := create2(0, add(bytecode, 0x20), mload(bytecode), salt)
        }
    }

    //创建token并铸造
    //成功示例https://goerli.etherscan.io/tx/0xddbf49cf10f7f8f9b8cd0ea1684b0ee2da8c8b0c05a57c3eff8ab4befd2a5c61
    function createTokenAAndTokenB(
        uint256 _value,
        bytes32 _salt,
        Token calldata token1,
        Token calldata token2
    ) external nonReentrant isHuman returns (address tokenA, address tokenB) {
        {
            _salt = bytes32(
                block.timestamp +
                uint256(uint160(address(this))) +
                uint256(_salt)
            );
            require(keccak256(bytes(token1.name)) != keccak256(bytes(token2.name)) && keccak256(bytes(token1.symbol)) != keccak256(bytes(token2.symbol)),"Compare failed");
            bytes memory deployBytecode = abi.encodePacked(
                erc20Bytecode,
                abi.encode(token1.name, token1.symbol)
            );
            bytes memory deployBytecode2 = abi.encodePacked(
                erc20Bytecode,
                abi.encode(token2.name, token2.symbol)
            );
            tokenA = create(deployBytecode, _salt);
            tokenB = create(deployBytecode2, _salt);
            require(
                tokenA != address(0) && tokenB != address(0),
                "tokenA and tokenB create failed"
            );
            address to = msg.sender;
            MultERC20(tokenA).mint(to, _value);
            MultERC20(tokenB).mint(to, _value);
            MultERC20(tokenA).transferOwnership(to);
            MultERC20(tokenB).transferOwnership(to);
            emit CreateTokenAndTokenB(to, tokenA, tokenB);
        }
    }

    //由于用户没有eth用于测试,所以本合约存入一点以太坊
    //给用户用于添加流动性
    function depositETH() external payable isHuman {
        address from = msg.sender;
        require(msg.value > 0, "The deposited Ethereum must be greater than 0");
        if (from == manager) {
            (bool success, ) = address(this).call{value: msg.value, gas: 2300}(
                ""
            );
            require(success, "Failed to deposit eth!");
        } else {
            (bool success, ) = address(this).call{value: msg.value, gas: 2300}(
                ""
            );
            require(success, "Failed to deposit eth!");
            userBlanceOf[from] = msg.value;
        }
    }

    //取出eth
    function withdrawETH() external isHuman {
        address from = msg.sender;
        if (address(this).balance > 0) {
            if (from == manager) {
                (bool success, ) = from.call{
                    value: address(this).balance,
                    gas: 2300
                }("");
                require(success, "Failed to withdraw eth!");
            } else {
                if (userBlanceOf[from] > 0) {
                    (bool success, ) = from.call{
                        value: userBlanceOf[from],
                        gas: 2300
                    }("");
                    require(success, "Failed to withdraw eth!");
                }
            }
        }
    }

    //存入token
    //先approve才行
    //再执行此函数
    function depositToken(address token, uint256 _amount) external isHuman {
        require(_amount > 0, "Invalid data entered");
        address from = msg.sender;
        MultERC20(token).transferFrom(from, address(this), _amount * 10 ** 18);
        userBalanceTokenOf[from][token] = _amount * 10 ** 18;
    }

    //取出token
    function withdrawToken(
        address token,
        address to,
        uint256 amount
    ) external isHuman {
        address from = msg.sender;
        if (MultERC20(token).balanceOf(address(this)) > 0) {
            if (from == manager) {
                MultERC20(token).transfer(manager, amount * 10 ** 18);
            } else {
                if (userBalanceTokenOf[from][token] > 0) {
                    MultERC20(token).transfer(to, amount * 10 ** 18);
                    userBalanceTokenOf[from][token] = 0;
                } else {
                    revert("Exceeded the deposited token!");
                }
            }
        }
    }

    //取消erc20授权
    function cancelApprove(address token, address authorizedContract) external {
        MultERC20(token).approve(authorizedContract, 0);
    }

    //创建token与eth的流动性
    //成功示例https://goerli.etherscan.io/tx/0xa23e5ffc1a41419c49e7422c0952a4b7ee9c14ee0c95ad811aceec42c60655c2
    function addTokenAndEthPairs(
        TokenParms memory token,
        uint amountETHMin
    )
        external
        payable
        isHuman
        returns (uint amountToken, uint amountETH, uint liquidity)
    {
        //MultERC20(token).permit(owner,address(this),value,deadline,v,r,s);
        //MultERC20(token).transferFrom(owner,address(this),value,deadline,v,r,s);
        require(msg.value > 0, "The deposited Ethereum must be greater than 0");
        //查询下用户授权的token数量
        address from = msg.sender;
        uint256 _amount = MultERC20(token.token).allowance(from, address(this));
        if (_amount == 0) revert("Please re-authorize the amount to the current contract!");
        MultERC20(token.token).transferFrom(from, address(this), _amount);
        token.amountTokenDesired = _amount;
        token.amountTokenMin = 0;
        MultERC20(token.token).approve(
            uniswapV2Router,
            token.amountTokenDesired
        );
        token.deadline = block.timestamp > token.deadline
            ? block.timestamp
            : token.deadline;
        userBlanceOf[from] = msg.value;
        (bool success, bytes memory data) = uniswapV2Router.call{
            value: userBlanceOf[from]
        }(
            abi.encodeWithSignature(
                "addLiquidityETH(address,uint256,uint256,uint256,address,uint256)",
                token.token,
                token.amountTokenDesired,
                token.amountTokenMin,
                amountETHMin,
                token.to,
                token.deadline
            )
        );
        require(success && data.length > 0, "AddLiquidity failed");
        (amountToken, amountETH, liquidity) = abi.decode(
            data,
            (uint256, uint256, uint256)
        );
        userBlanceOf[from] = 0;
        //获取添加流动性交易对的合约地址
        address lp = getPair(token.token, uniswapV2WETH);
        emit CreateTokenAndTokenBPairs(from, lp);
    }

    //创建token与token的流动性
    //成功示例https://goerli.etherscan.io/tx/0x498c0cf5c70c292e5ab2467209b04801f489d5b107e4a39e36bd8d0b25680a02
    function addTokenToTokenPairs(
        TokenParms memory token0,
        TokenParms memory token1
    )
        external
        isHuman
        returns (uint amountA, uint amountB, uint liquidity)
    {
        //会报堆栈太深的问题,减少局部变量的使用
        uint256[2] memory arr;
        address from = msg.sender;
        arr[0] = MultERC20(token0.token).allowance(from, address(this));
        arr[1] = MultERC20(token1.token).allowance(from, address(this));
        if (arr[0] == 0 || arr[1] == 0) revert("Please re-authorize the amount to the current contract!");
        MultERC20(token0.token).transferFrom(from, address(this), arr[0]);
        MultERC20(token1.token).transferFrom(from, address(this), arr[1]);
        token0.amountTokenDesired = arr[0];
        token0.amountTokenMin = 0;
        token1.amountTokenDesired = arr[1];
        token1.amountTokenMin = 0;
        MultERC20(token0.token).approve(
            uniswapV2Router,
            token0.amountTokenDesired
        );
        MultERC20(token1.token).approve(
            uniswapV2Router,
            token1.amountTokenDesired
        );
        token1.deadline = block.timestamp > token1.deadline
            ? block.timestamp
            : token1.deadline;
        (bool success, bytes memory data) = uniswapV2Router.call(
            abi.encodeWithSignature(
                "addLiquidity(address,address,uint256,uint256,uint256,uint256,address,uint256)",
                token0.token,
                token1.token,
                token0.amountTokenDesired,
                token1.amountTokenDesired,
                token0.amountTokenMin,
                token1.amountTokenMin,
                token1.to,
                token1.deadline
            )
        );
        require(success && data.length > 0, "addLiquidity failed");
        (amountA, amountB, liquidity) = abi.decode(
            data,
            (uint256, uint256, uint256)
        );
        //获取添加流动性交易对的合约地址
        address lp = getPair(token0.token, token1.token);
        emit CreateTokenAndTokenBPairs(from, lp);
    }

    //查询某地址持有的token,eth包括合约
    function getAddrBalance(
        address token,
        address addr
    ) external view returns (uint256 tokenBalance, uint256 ethBalance) {
        (bool success, bytes memory data) = token.staticcall(
            abi.encodeWithSignature("balanceOf(address)", addr)
        );
        require(success && data.length > 0, "getTokenBalance failed");
        (tokenBalance) = abi.decode(data, (uint256));
        address from = msg.sender;
        ethBalance = addr == address(this)
            ? address(this).balance
            : from.balance;
    }

    //查询任何地址持有的LP Token
    function getOwnedToken(
        address LPToken,
        address owner
    ) external view returns (uint256 amount) {
        amount = IUniswapV2Pair(LPToken).balanceOf(owner);
    }

    //返回token与token交易对合约的各自库存数量
    function getTokenAAndTokenBReserves(
        address LPToken
    ) public view returns (uint112, uint112) {
        (uint112 tokenA, uint112 tokenB, ) = IUniswapV2Pair(LPToken)
            .getReserves();
        return (tokenA, tokenB);
    }

    //获取添加流动性产生的交易对合约地址
    function getPair(
        address tokenA,
        address tokenB
    ) public view returns (address pair) {
        (bool success, bytes memory data) = uniswapV2Factory.staticcall(
            abi.encodeWithSignature("getPair(address,address)", tokenA, tokenB)
        );
        require(success && data.length > 0, "getPair failed");
        (pair) = abi.decode(data, (address));
    }

    //获取交易对中的tokenA与tokenB
    function getTokenbAAndTokenB(
        address LPToken
    ) public view returns (address tokenA, address tokenB) {
        tokenA = IUniswapV2Pair(LPToken).token0();
        tokenB = IUniswapV2Pair(LPToken).token1();
    }

    //预估,例如tokenA可以兑换多少tokenB还有反过来的操作
    //这能准确预估到实际到手的token数量
    function getAmountsOut(
        uint256 amountIn,
        address[] calldata path
    ) public view returns (uint256[] memory amounts) {
        //根据前端输入的数量获取兑换的token数量
        (bool success, bytes memory data) = uniswapV2Router.staticcall(
            abi.encodeWithSignature(
                "getAmountsOut(uint256,address[])",
                amountIn,
                path
            )
        );
        require(success && data.length > 0, "calculate failed");
        amounts = abi.decode(data, (uint256[]));
    }

    //参数reserveIn是tokenA的储备量
    //参数reserveOut是tokenB的储备量
    //amountIn是兑换的tokenA
    //amountOut是用tokenA兑换的tokenB的数量,是最后我们想得到的toeknB数量
    //这个方法能得到实际最终获取的token数量,是很准确的
    //这涉及到一个公式
    /*根据 AMM 的原理，恒定乘积公式「x * y = K」，兑换前后 K 值不变。因此，在不考虑交易手续费的情况下，以下公式会成立：
    reserveIn * reserveOut = (reserveIn + amountIn) * (reserveOut - amountOut)
    可参考https://mp.weixin.qq.com/s?__biz=MzA5OTI1NDE0Mw==&mid=2652494370&idx=1&sn=f825dfd0c71e09c7a86d5caab18df139&chksm=8b685032bc1fd9246e52293c9916771f524ede972347678e691cdb1fb847eff7e91b8ef3a920&scene=178&cur_album_id=1900659726451834889#rd
    这个文章解答疑惑
*/
    function getAmountOut(
        uint amountIn,
        address lp
    ) public view returns (uint amountOut) {
        (uint112 reserveIn,uint112 reserveOut) = getTokenAAndTokenBReserves(lp);
        (bool success, bytes memory data) = uniswapV2Router.staticcall(
            abi.encodeWithSignature(
                "getAmountOut(uint256,uint256,uint256)",
                amountIn,
                reserveIn,
                reserveOut
            )
        );
        require(success && data.length > 0, "calculate failed");
        amountOut = abi.decode(data, (uint256));
    }

    //根据输入token输出数量,兑换路径path获取计算得到兑换路径中每个交易对的输入数量
    function getAmountsIn(
        uint amountOut,
        address[] calldata path
    ) public view returns (uint[] memory amounts) {
        (bool success, bytes memory data) = uniswapV2Router.staticcall(
            abi.encodeWithSignature(
                "getAmountsIn(uint256,address[])",
                amountOut,
                path
            )
        );
        require(success && data.length > 0, "calculate failed");
        amounts = abi.decode(data, (uint256[]));
    }

    //这个方法类似getAmountOut方法
    //也就是通过最终获取的tokenB去推断我们要实际输入的tokenA数量
    //amountOut是我们实际拿tokenA兑换得到多少tokenB的数量
    //reserveIn是tokenA的储备量
    //reserveOut是tokenB的储备量
    //amountIn是tokenA实际要输入的数量
    function getAmountIn(
        uint amountOut,
        address lp
    ) public view returns (uint amountIn) {
        (uint112 reserveIn,uint112 reserveOut) = getTokenAAndTokenBReserves(lp);
        (bool success, bytes memory data) = uniswapV2Router.staticcall(
            abi.encodeWithSignature(
                "getAmountIn(uint256,uint256,uint256)",
                amountOut,
                reserveIn,
                reserveOut
            )
        );
        require(success && data.length > 0, "calculate failed");
        amountIn = abi.decode(data, (uint256));
    }

    //预估用tokenA兑换tokenB能得到到手的tokenB,这只是预估能到手的,不代表实际到手的数量
    //如果要预估实际到手的数量使用getAmountsOut
    function quote(uint amountA, address lp) public view returns (uint amountB) {
        //先获取tokewnA与tokenB的储备量
        (uint112 reserveA, uint112 reserveB) = getTokenAAndTokenBReserves(lp);
        (bool success, bytes memory data) = uniswapV2Router.staticcall(
            abi.encodeWithSignature(
                "quote(uint256,uint256,uint256)",
                amountA,
                reserveA,
                reserveB
            )
        );
        require(success && data.length > 0, "calculate failed");
        amountB = abi.decode(data, (uint256));
    }


    //通过uniswap合约进行兑换
    //eth兑换token
    //此函数一般用于出售确定数量的ETH,获得不确定数量代币
    //参数path顺序可以随便写
    //成功示例https://goerli.etherscan.io/tx/0x40eac64b5ecaff36145883a7be13be934f88daf25cd8257ce0e4bc62fcd6002c
    function swapExactETHForTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable isHuman returns (uint256[] memory amounts) {
        //注释的代码只能在前端给或者后端操作
        require(
            msg.value > 0 && amountOutMin > 0,
            "Ethereum must be greater than 0!"
        );
        deadline = block.timestamp > deadline ? block.timestamp : deadline;
        //getTokenToEthAmountOut返回的是输入的金额amountOutMin,实际预期可以兑换到的token数量
        uint256[] memory amountsExpected = getAmountsOut(amountOutMin, path);
        amountOutMin = amountsExpected[1];
        address from = msg.sender;
        userBlanceOf[from] = msg.value;
        (bool success, bytes memory data) = uniswapV2Router.call{
            value: userBlanceOf[from]
        }(
            abi.encodeWithSignature(
                "swapExactETHForTokens(uint256,address[],address,uint256)",
                amountOutMin*10**18,
                path,
                to,
                deadline
            )
        );
        require(success && data.length > 0, "swapExactETHForTokens failed");
        amounts = abi.decode(data, (uint256[]));
        userBlanceOf[from] = 0;
    }

    //通过uniswap合约进行兑换
    //eth兑换token
    //此函数一般用于购买确定数量代币,支付不确定数量的ETH
    //amountOut是我们实际拿tokenA(即eth)兑换得到多少tokenB的数量
    //如果amountOut是输入的精确的tokenB数量
    //以太坊必须大于等于计算的以太坊,多余的以太坊会退回到合约去
    //成功示例https://goerli.etherscan.io/tx/0x30f2308262b7b911bf54f66482681b61957edec0977e7adf22eeb06c776ec0ac
    function swapETHForExactTokens(
        uint amountOut,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable isHuman returns (uint256[] memory amounts) {
        require(msg.value > 0, "Ethereum must be greater than 0!");
        deadline = block.timestamp > deadline ? block.timestamp : deadline;
        address from = msg.sender;
        userBlanceOf[from] = msg.value;
        (bool success2, bytes memory _data) = uniswapV2Router.call{
            value: userBlanceOf[from]
        }(
            abi.encodeWithSignature(
                "swapETHForExactTokens(uint256,address[],address,uint256)",
                amountOut*10**18,
                path,
                to,
                deadline
            )
        );
        require(success2  && _data.length > 0, "swapExactETHForTokens failed");
        amounts = abi.decode(_data, (uint256[]));
        if(userBlanceOf[from] > 0 && amounts[0] > 0){
            //用户从当前合约赎回兑换后退回到当前合约的以太坊
            (bool success, ) = from.call{value: userBlanceOf[from] - amounts[0], gas: 2300}(
               new bytes(0)
            );
            require(success, "Failed to deposit eth!");
            userBlanceOf[from] = 0;
         }      
    }

    //通过uniswap合约进行兑换
    //token兑换eth
    //输入精确数量代币的顺序兑换不确定eth
    //token是兑换得tokenA合约地址
    //amountIn是tokenA输入的代币数量
    //amountOutMin是tokenB的最小数量,为了方便传参的时候可以传参为0
    //path即tokenA与tokenB地址,这里path数组的最后一个元素是weth合约地址
    //to是拿tokenA兑换以太坊(即tokenB)接收兑换后的以太坊地址
    //deadline是截止时间,为了方便传参的时候可以传参为0
    //amounts下标0的结果是,下标1是
    //成功示例https://goerli.etherscan.io/tx/0xc312190d6d59973bd775d08709d56e0b73a6a60b9fc5d132ea61b18a0a6519a8
    function swapExactTokensForETH(
        address token,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external isHuman returns (uint256[] memory amounts) {
        //先approve给到当前合约
        address from = msg.sender;
        uint256 _amount = MultERC20(token).allowance(from, address(this));
        if (_amount == 0)  revert("Please re-authorize the amount to the current contract!");
        uint256 amountIn = _amount;
        MultERC20(token).transferFrom(from, address(this), _amount);
        MultERC20(token).approve(uniswapV2Router, _amount);
        deadline = block.timestamp > deadline ? block.timestamp : deadline;
        //后续会增加预期获取到的token数量
        (bool success, bytes memory data) = uniswapV2Router.call(
            abi.encodeWithSignature(
                "swapExactTokensForETH(uint256,uint256,address[],address,uint256)",
                amountIn,
                amountOutMin*10**18,
                path,
                to,
                deadline
            )
        );
        require(success && data.length > 0, "swapExactTokensForETH failed");
        amounts = abi.decode(data, (uint256[]));
    }

    //通过uniswap合约进行兑换
    //token兑换eth
    //此函数一般用于购买确定数量的 ETH，用不定数量的代币交换
    //amountOut指兑换后的eth,是我们输入的一个精确的以太坊值,也就是最后我们兑换后一定得到的以太坊值
    //amountInMax指输入的token数量的最大值，最大值可以设置很大,因为实际兑换以amountOut等值得token
    //path指交易对路径，这里path数组的最后一个元素是weth合约地址
    //to接收以太坊地址
    //deadline是截止时间,为了方便传参可以为0
    //amounts[0]指的是实际输入的tokenA数量也就是实际拿去兑换的tokenA数量
    //amounts[1]指的是实际输出的的tokenB数量等同于amountOut
    /*逻辑分析由于使用的是合约交互uiniswapV2合约,所以需要先approve给到当前合约,然后再调用uiniswapV2合约的swapTokensForExactETH接口实现兑换
    */
   //成功示例https://goerli.etherscan.io/tx/0xd587efa1857733ceccc2aad3e246d5062932e116fac07dd623aa45379a5604fc
    function swapTokensForExactETH(
        address token,
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable isHuman returns (uint256[] memory amounts) {
        //先approve给到当前合约
        address from = msg.sender;
        uint256 _amount = MultERC20(token).allowance(from, address(this));
        if (_amount == 0) revert("Please re-authorize the amount to the current contract!");
        MultERC20(token).transferFrom(from, address(this), _amount);
        MultERC20(token).approve(uniswapV2Router, _amount);
        deadline = block.timestamp > deadline ? block.timestamp : deadline;
        (bool success, bytes memory data) = uniswapV2Router.call(
            abi.encodeWithSignature(
                "swapTokensForExactETH(uint256,uint256,address[],address,uint256)",
                amountOut,
                amountInMax,
                path,
                to,
                deadline
            )
        );
        require(success && data.length > 0, "swapExactTokensForETH failed");
        amounts = abi.decode(data, (uint256[]));
        //将剩余的token从当前合约退回到用户
        if(_amount - amounts[0] > 0 && amounts.length > 0) MultERC20(token).transfer(from, _amount - amounts[0]);    
    }

    //通过uniswap合约进行兑换
    //token兑换token(token兑换以太坊也可以)
    //实现了用户使用数量精确的 tokenA 交易数量不精确的 tokenB
    //path是指路径,也就是填写所需兑换的tokenA合约地址,tokenB合约地址
    //amountIn即前端交易支付代币数量,说白了就是tokenA的数量是一个固定也是全部拿去兑换的数量
    //amountOutMin即前端交易获得代币最小值,也就是我们想兑换得到的tokenB
    //成功示例https://goerli.etherscan.io/tx/0x56fe0dce18a4982b0b56912020945b72aed801eb7271764f1cf1db747983a741
    function swapExactTokensForTokens(
        address token,
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external isHuman returns (uint256[] memory amounts) {
        //先approve给到当前合约
        address from = msg.sender;
        uint256 _amount = MultERC20(token).allowance(from, address(this));
        if (_amount == 0) revert("Please re-authorize the amount to the current contract!");
        MultERC20(token).transferFrom(from, address(this), amountIn);
        //再approve给到uniswapV2RouterV1
        MultERC20(token).approve(uniswapV2Router, amountIn);
        deadline = block.timestamp > deadline ? block.timestamp : deadline;
        (bool success, bytes memory data) = uniswapV2Router.call(
            abi.encodeWithSignature(
                "swapExactTokensForTokens(uint256,uint256,address[],address,uint256)",
                amountIn,
                amountOutMin,
                path,
                to,
                deadline
            )
        );
        require(success && data.length > 0, "swapExactTokensForTokens failed");
        amounts = abi.decode(data, (uint256[]));
    }

    //通过uniswap合约进行兑换
    //token兑换token
    //用于购买确定数量的代币
    //amountOut指兑换后的tokenB的数量是一个固定的数量,由个人自己输入确定
    //amountInMax指前端支付tokenA最大数量,也是一个固定的数量,可以自己指定
    //amounts[0]指的是tokenA实际需要支付的tokenA
    //amounts[1]指的是tokenB也是amountOut的值
    //这里只能是token和token,不能是以太坊和token
    //成功示例https://goerli.etherscan.io/tx/0x032c4a8f24fb69dfac8c01cf29b1b1a5f82d56586231822ae7ec67023670e6e9
    //参数图片https://bafkreihrgxi6i4chsfgibzkn2o7xqnig6xjfc564knjzcchm3ofnmekvz4.ipfs.nftstorage.link/
    function swapTokensForExactTokens(
        address token,
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external isHuman returns (uint256[] memory amounts) {
        address from = msg.sender;
        uint256 out = MultERC20(token).allowance(from, address(this));
        if (out == 0) revert("Please re-authorize the amount to the current contract!");
        MultERC20(token).transferFrom(from, address(this), out);
        //再approve给到uniswapV2Router
        MultERC20(token).approve(uniswapV2Router, out);
        deadline = block.timestamp > deadline ? block.timestamp : deadline;
        (bool success, bytes memory data) = uniswapV2Router.call(
            abi.encodeWithSignature(
                "swapTokensForExactTokens(uint256,uint256,address[],address,uint256)",
                amountOut,
                amountInMax,
                path,
                to,
                deadline
            )
        );
        require(success && data.length > 0, "swapTokensForExactTokens failed");
        amounts = abi.decode(data, (uint256[]));
        //再将剩余的tokenA退还给用户
        if(out - amounts[0] > 0 && amounts.length > 0) MultERC20(token).transfer(from,out - amounts[0]);  
    }

    //通过uniswapV2合约移除流动性
    //移除token to token流动性
    /*整个逻辑
    第一步https://goerli.etherscan.io/tx/0x85dd861da94f50320daffac807811bd04ba8ecea601564761eed0444e28136fa
    第二步调用此合约此方法removeLiquidity即可
    */
    //成功示例https://goerli.etherscan.io/tx/0x0342faf484d3748445abd55328c9d16671be7d9b5a859294cc33a7180126a956
    //参数示例https://bafkreie222wkwhjgsfa3vjelun4djc6ynxa2nxaw6bgczdmrhdp5lrk7q4.ipfs.nftstorage.link/
    function removeLiquidity(
        address LPToken,
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external isHuman returns (uint256 amountA, uint256 amountB) {
        IUniswapV2Pair(LPToken).approve(uniswapV2Router, liquidity);
        deadline = block.timestamp > deadline ? block.timestamp : deadline;
        (bool success, bytes memory data) = uniswapV2Router.call(
            abi.encodeWithSignature(
                "removeLiquidity(address,address,uint256,uint256,uint256,address,uint256)",
                tokenA,
                tokenB,
                liquidity,
                amountAMin,
                amountBMin,
                to,
                deadline
            )
        );
        require(success && data.length > 0, "removeTokenToTokenLiquidity failed");
        (amountA, amountB) = abi.decode(data, (uint256, uint256));
    }

    //移除token与eth流动性
    /*整个逻辑
    第一步执行https://goerli.etherscan.io/tx/0xf1f4ee9d229bb30b03cdabf37f91b6d79beb5490e990bb2f127a8ebe72007704
    第二步调用此合约此方法removeLiquidityETH即可
    */
    //成功示例https://goerli.etherscan.io/tx/0xf2243086a02d2eb43ad2f1b1c9d2286abee0b7b299ec0aa3d9bd83961a57e638
    //参数示例https://bafkreib63l4monikyusqefax5ypc4wxn6oofjaip4qgk3yjb75c3z2zsgy.ipfs.nftstorage.link/
    function removeLiquidityETH(
        address LPToken,
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external isHuman returns (uint256 amountA, uint256 amountB) {
        IUniswapV2Pair(LPToken).approve(uniswapV2Router, liquidity);
        deadline = block.timestamp > deadline ? block.timestamp : deadline;
        (bool success, bytes memory data) = uniswapV2Router.call(
            abi.encodeWithSignature(
                "removeLiquidityETH(address,uint256,uint256,uint256,address,uint256)",
                token,
                liquidity,
                amountTokenMin,
                amountETHMin,
                to,
                deadline
            )
        );
        require(success && data.length > 0, "removeTokenToEthLiquidity failed");
        (amountA, amountB) = abi.decode(data, (uint256, uint256));
    }

    function preFlashSwap(
        address[] memory path,
        uint256 amount
    ) internal pure returns (bytes memory data) {
        data = abi.encode(path, amount);
    }

    function flashSwap(
        address LP,
        uint amount0,
        uint amount1,
        uint256 _amountOutMin
    ) external isHuman {
        //先假设amount0 = 输入借款的eth数量 ,amount1 = 0;
        address[] memory path = new address[](2);
        uint amountToken;
        uint amountETH;
        address token0 = IUniswapV2Pair(LP).token0(); //weth
        address token1 = IUniswapV2Pair(LP).token1(); //token
        require(
            amount0 == 0 || amount1 == 0,
            "Make sure the quantity entered has a quantity of 0!"
        ); // this strategy is unidirectional
        path[0] = amount0 == 0 ? token0 : token1; //如果amount0等于0,path[0]等于weth
        path[1] = amount0 == 0 ? token1 : token0; //如果amount0等于0,path[1]等于要兑换的token地址
        amountToken = token0 == address(uniswapV2WETH) ? amount1 : amount0; //token0地址等于weth,那么amount1等于amountToken，我们暂时给它设为0
        amountETH = token0 == address(uniswapV2WETH) ? amount0 : amount1; //token0地址等于weth,那么amount0等于amountETH
        // 所以amount1 = 0, amount0 = 我们要借取的eth数量
        require(
            path[0] == address(uniswapV2WETH) ||
                path[1] == address(uniswapV2WETH),
            "Make sure there is a path to our WETH address!"
        ); // this strategy only works with a V2 WETH pair
        //获取要兑换的token
        //MultERC20 token = MultERC20(path[0] == address(uniswapV2WETH) ? path[1] : path[0]);

        if (amountToken > 0) {
            bytes memory _data = preFlashSwap(path, amountToken);
            IUniswapV2Pair(LP).swap(amount0, amountToken, address(this), _data);
        } else {
            bytes memory _data = preFlashSwap(path, amountETH);
            IUniswapV2Pair(LP).swap(amount1, amountETH, address(this), _data);
        }
    }

    /*************************************************闪电贷借token示例********************************************/
    //所有换种思路，也就是我借出eth或token直接,然后还token
    //还eth或token之前，我们先打点eth和token给到当前合约即可
    //暂时这步骤我们先借出token吧,然后归还token
    //uniswapV2Call这方法的主要作用其实主要就是用于还款的
    //成功借token并还token示例https://goerli.etherscan.io/tx/0x96204ef8c8e297d5e8377c95b37af83f5ec904d4e425ea6dfc8fa0ad2b904fc5
    function uniswapV2Call(
        address sender,
        uint amount0,
        uint amount1,
        bytes calldata data
    ) public {
        address lp = msg.sender;
        //先解码abi
        (address[] memory path, uint amountOut) = abi.decode(
            data,
            (address[], uint256)
        );
        //千分之3的手续费
        uint fee = ((amountOut * 3) / 997) + 1;
        uint returnTotal = fee + amountOut;
        //归还token
        MultERC20(path[1]).transfer(lp, returnTotal);
    }

}
