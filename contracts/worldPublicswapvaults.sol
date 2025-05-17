// SPDX-License-Identifier: Business Source License 1.1
// First Release Time : 2025.05.18

// Save all assets and enter and exit assets by calling the core's algorithm swap 
// or increasing||decreasing lp through lpmanager;
// All information of the currency pairs is also saved in this contract


pragma solidity 0.8.6;
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./libraries/structlibrary.sol";
import "./interfaces/iworldPublicswappair.sol";
import "./interfaces/iworldPublicfactory.sol";

// World Public Swap

contract worldPublicSwapVaults{
    using SafeERC20 for IERC20;

    //----------------------Persistent Variables ----------------------
    uint public constant MINIMUM_LIQUIDITY = 10**3;
    
    address public slc;
    address public lpManager;
    address public factory;
    address public setter;
    address newsetter;
    mapping (address=>bool) public xInterface;

    mapping (address=>structlibrary.reserve) public reserves;
    mapping (address=>uint) public relativeTokenUpperLimit; // init is 1 ether

    mapping (address => mapping(address => address)) public getPair;
    mapping (address => address) public getCoinToStableLpPair;
    address[] public allPairsInVault;

    uint latestBlockNumber;

    uint public minLpLimit;      // Default settings 100 
    uint public mintListLimit;   // Default settings 1,000 

    //----------------------------modifier ----------------------------
    uint private unlocked = 1;
    modifier lock() {
        require(unlocked == 1, 'World Swap Vaults: LOCKED');
        unlocked = 0;
        _;
        unlocked = 1;
    }
    modifier onlyLpManager() {
        require(msg.sender == lpManager, 'World Swap Vaults: Only Lp Manager Use');
        _;
    }
    modifier onlyLpSetter() {
        require(msg.sender == setter, 'World Swap Vaults: Only Lp setter Use');
        _;
    }

    //-------------------------- constructor --------------------------
    constructor() {
        setter = msg.sender;
    }
    //----------------------------- event -----------------------------
    event SystemSetup(address _slc,address _lpManager,address _factory);
    event Interfacesetting(address _xInterface, bool _ToF);
    event TransferLpSetter(address _set);
    event AcceptLpSetter(bool _TorF);

    event Subscribe(address indexed lp, address subscribeAddress, uint lpAmount);
    event Redeem(address indexed lp, address redeemAddress, uint lpAmount);

    event CreatLpVault(address _lp,address[2] _tokens,uint8 lpCategory) ;
    event IncreaseLpAmount(address _lp,uint[2] _reserveIn,uint _lpAdd);
    event DereaseLpAmount(address _lp,uint[2] _reserveOut,uint _lpDel);
    event LpSettings(address _lp, uint32 _balanceFee, uint _a0) ;

    event worldPublicExchange(address indexed inputToken, address indexed outputToken,uint inputAmount,uint outputAmount);
    //----------------------------- ----- -----------------------------

    function systemSetup(address _slc,address _lpManager,address _factory) external onlyLpSetter{
            slc = _slc;
            lpManager = _lpManager;
            factory = _factory;
        emit SystemSetup(_slc, _lpManager, _factory);
    }

    function xInterfacesetting(address _xInterface, bool _ToF)external onlyLpSetter{
        xInterface[_xInterface] = _ToF;
        emit Interfacesetting( _xInterface, _ToF);
    }

    function transferLpSetter(address _set) external onlyLpSetter{
        newsetter = _set;
        emit TransferLpSetter(_set);
    }
    function acceptLpSetter(bool _TorF) external {
        require(msg.sender == newsetter, 'World Swap Vaults: Permission FORBIDDEN');
        if(_TorF){
            setter = newsetter;
        }
        newsetter = address(0);
        emit AcceptLpSetter(_TorF);
    }
    function exceptionTransfer(address recipient) external onlyLpSetter{
        require(address(this).balance>0,"World Swap Vaults: Insufficient amount");
        transferCFX(recipient,address(this).balance);
    }
    function transferCFX(address _recipient,uint256 _amount) private {
        require(address(this).balance>=_amount,"World Swap Vaults: Exceed the storage CFX balance");
        address payable receiver = payable(_recipient); // Set receiver
        (bool success, ) = receiver.call{value:_amount}("");
        require(success,"World Swap Vaults: CFX Transfer Failed");
    }
        //--------------------------- x Lp Subscribe & Redeem functions --------------------------

    function xLpSubscribe(address _lp,uint[2] memory _amountEstimated) external lock returns(uint[2] memory _amountActual,uint _amountLp){

        address[2] memory assetAddr;
        uint8 category;
        uint[2] memory reserve;           
        uint[2] memory priceCumulative;
        uint totalSupply;
        (assetAddr,category) = iworldPublicFactory(factory).getLpPairsDetails( _lp);
        (reserve,priceCumulative,totalSupply) = getLpReserve( _lp);

        require(assetAddr[0] != address(0),"World Swap LpManager: assetAddr can't be address(0) ");
        require(assetAddr[1] != address(0),"World Swap LpManager: assetAddr can't be address(0) ");

        if(reserve[0]==0){// First LP, will transfer to LpVault, can redeem when on other Lps; 

            require(reserve[1]==0,"World Swap LpManager: two reserve MUST be ZERO");//first Lp, need a 1000 xusd amount
            if(category==1){
                require(_amountEstimated[1] >= mintListLimit * 1 ether,"World Swap LpManager: First Lp need init SLC");
                require(_amountEstimated[0] >= 1000000,"World Swap LpManager: Cant Be a too small amount");
                _amountLp = _amountEstimated[1];
                _amountActual[0] = _amountEstimated[0];
                _amountActual[1] = _amountEstimated[1];
            }else if(category==2) {

                _amountActual[0] = _amountEstimated[0] * getLpPrice(iworldPublicFactory(factory).getCoinToStableLpPair(assetAddr[0]))/ 1 ether;

                _amountActual[1] = _amountEstimated[1] * getLpPrice(iworldPublicFactory(factory).getCoinToStableLpPair(assetAddr[1]))/ 1 ether;

                require(_amountActual[0] >= minLpLimit * 1 ether && _amountActual[1] >= minLpLimit * 1 ether,"World Swap LpManager: First Lp need init SLC Value");
                if(_amountActual[0]>=_amountActual[1]){
                    _amountLp = _amountActual[1];
                    _amountActual[0] = _amountActual[1] * 1 ether / getLpPrice(iworldPublicFactory(factory).getCoinToStableLpPair(assetAddr[0]));
                    _amountActual[1] = _amountEstimated[1];
                }else{
                    _amountLp = _amountActual[0];
                    _amountActual[1] = _amountActual[0] * 1 ether / getLpPrice(iworldPublicFactory(factory).getCoinToStableLpPair(assetAddr[1]));
                    _amountActual[0] = _amountEstimated[0];
                }
            }
            lpSettings(_lp, 30, 0);
            creatLpVault(_lp,assetAddr,category);//
        }else{// Subsequent LP addition, Lp will transfer to msg.sender; 
            _amountActual[0] = _amountEstimated[1]*reserve[0]/reserve[1];
            if(_amountActual[0]<=_amountEstimated[0]){
                _amountActual[1] = _amountEstimated[1];
            }else{
                _amountActual[0] = _amountEstimated[0];
                _amountActual[1] = _amountEstimated[0]*reserve[1]/reserve[0];
            }
            _amountLp = _amountActual[0] * totalSupply / reserve[0];
        }
        // here need add info change
        uint[2] memory totalTokenInVaults;
        totalTokenInVaults[0] = IERC20(assetAddr[0]).balanceOf(address(this));
        totalTokenInVaults[1] = IERC20(assetAddr[1]).balanceOf(address(this));
        

        IERC20(assetAddr[0]).safeTransferFrom(msg.sender,address(this),_amountActual[0]);
        IERC20(assetAddr[1]).safeTransferFrom(msg.sender,address(this),_amountActual[1]);

        require(_amountActual[0] == IERC20(assetAddr[0]).balanceOf(address(this)) - totalTokenInVaults[0],"World Swap LpManager: Cannot compatible with tokens with transaction fees");
        require(_amountActual[1] == IERC20(assetAddr[1]).balanceOf(address(this)) - totalTokenInVaults[1],"World Swap LpManager: Cannot compatible with tokens with transaction fees");

        increaseLpAmount(_lp, _amountActual,_amountLp);
        
        iworldPublicSwapPair(_lp).mintXLp(msg.sender, _amountLp);
        emit Subscribe(_lp, msg.sender, _amountLp);
        
    }

    function xLpRedeem(address _lp,uint _amountLp) external lock returns(uint[2] memory _amount){
        require(_lp != address(0),"World Swap LpManager: _lp can't be address(0) ");
        require(_amountLp > 0,"World Swap LpManager: _amountLp must > 0");
        address[2] memory assetAddr;
        uint8 category;
        uint[2] memory reserve;           
        uint totalSupply;
        (assetAddr,category) = iworldPublicFactory(factory).getLpPairsDetails( _lp);
        (reserve,,totalSupply) = getLpReserve( _lp);
        IERC20(_lp).safeTransferFrom(msg.sender,address(this),_amountLp);
        iworldPublicSwapPair(_lp).burnXLp(address(this), _amountLp);
        _amount[0] = reserve[0] * _amountLp /totalSupply;
        _amount[1] = reserve[1] * _amountLp /totalSupply;
        
        IERC20(assetAddr[0]).safeTransfer(msg.sender,_amount[0]);
        IERC20(assetAddr[1]).safeTransfer(msg.sender,_amount[1]);

        // here need add info change
        dereaseLpAmount(_lp, _amount,_amountLp);
        emit Redeem(_lp, msg.sender, _amountLp);
    }
    //----------------------------------------onlyLpManager Use Function------------------------------
    function creatLpVault(address _lp,address[2] memory _tokens,uint8 lpCategory) internal{
        require(reserves[_lp].assetAddr[0] == address(0),"World Swap Vaults: Already Have the Lp");

        reserves[_lp].assetAddr[0] = _tokens[0];
        reserves[_lp].assetAddr[1] = _tokens[1];
        reserves[_lp].category = lpCategory;
        IERC20(_tokens[0]).approve(lpManager, type(uint256).max);
        IERC20(_tokens[1]).approve(lpManager, type(uint256).max);
        allPairsInVault.push(_lp);
        getPair[_tokens[0]][_tokens[1]] = _lp;
        getPair[_tokens[1]][_tokens[0]] = _lp;
        if(lpCategory == 1){
            getCoinToStableLpPair[_tokens[0]]  = _lp;
        }
        emit CreatLpVault(_lp, _tokens, lpCategory);
    }

    function increaseLpAmount(address _lp,uint[2] memory _reserveIn,uint _lpAdd) internal{
        require(reserves[_lp].assetAddr[0] != address(0),"World Swap Vaults: Cant be Zero Tokens");
        address[2] memory reserveAddr = getLpPair( _lp) ;

        uint[2] memory totalTokenInVaults;
        totalTokenInVaults[0] = IERC20(reserveAddr[0]).balanceOf(address(this)) - _reserveIn[0];
        totalTokenInVaults[1] = IERC20(reserveAddr[1]).balanceOf(address(this)) - _reserveIn[1];

        if(reserves[_lp].reserve[0]==0 && reserves[_lp].reserve[1]==0){
            if(relativeTokenUpperLimit[reserveAddr[0]] == 0){
                reserves[_lp].reserve[0] = 1 ether;
                relativeTokenUpperLimit[reserveAddr[0]] = 1 ether;
            }else {
                reserves[_lp].reserve[0] += _reserveIn[0] * relativeTokenUpperLimit[reserveAddr[0]] / totalTokenInVaults[0];
                relativeTokenUpperLimit[reserveAddr[0]] += _reserveIn[0] * relativeTokenUpperLimit[reserveAddr[0]] / totalTokenInVaults[0];
            }
            if(relativeTokenUpperLimit[reserveAddr[1]] == 0){
                reserves[_lp].reserve[1] = 1 ether;
                relativeTokenUpperLimit[reserveAddr[1]] = 1 ether;
            }else{
                reserves[_lp].reserve[1] += _reserveIn[1] * relativeTokenUpperLimit[reserveAddr[1]] / totalTokenInVaults[1];
                relativeTokenUpperLimit[reserveAddr[1]] += _reserveIn[1] * relativeTokenUpperLimit[reserveAddr[1]] / totalTokenInVaults[1];
            }
            
            reserves[_lp].totalSupply = _lpAdd;
            reserves[_lp].priceCumulative[0] = _reserveIn[1];
            reserves[_lp].priceCumulative[1] = _reserveIn[0];

        }else{// this mode priceCumulative not change
            require(totalTokenInVaults[0]>0 && totalTokenInVaults[1]>0,"World Swap Vaults: total Token In Vaults Need > 0");
            reserves[_lp].reserve[0] += _reserveIn[0] * relativeTokenUpperLimit[reserveAddr[0]] / totalTokenInVaults[0];
            reserves[_lp].reserve[1] += _reserveIn[1] * relativeTokenUpperLimit[reserveAddr[1]] / totalTokenInVaults[1];
            relativeTokenUpperLimit[reserveAddr[0]] += _reserveIn[0] * relativeTokenUpperLimit[reserveAddr[0]] / totalTokenInVaults[0];
            relativeTokenUpperLimit[reserveAddr[1]] += _reserveIn[1] * relativeTokenUpperLimit[reserveAddr[1]] / totalTokenInVaults[1];
            reserves[_lp].totalSupply += _lpAdd;
        }
        emit IncreaseLpAmount(_lp,_reserveIn,_lpAdd);
    }
    function dereaseLpAmount(address _lp,uint[2] memory _reserveOut,uint _lpDel) internal{
        address[2] memory reserveAddr = getLpPair( _lp) ;
        uint[2] memory totalTokenInVaults;
        totalTokenInVaults[0] = IERC20(reserveAddr[0]).balanceOf(address(this)) + _reserveOut[0];//getLpTokenSum( _lp);//
        totalTokenInVaults[1] = IERC20(reserveAddr[1]).balanceOf(address(this)) + _reserveOut[1];
        require(totalTokenInVaults[0]>0&&totalTokenInVaults[1]>0,"World Swap Vaults: Vaults have NO reserve");
        reserves[_lp].reserve[0] -= _reserveOut[0] * relativeTokenUpperLimit[reserveAddr[0]]/totalTokenInVaults[0];
        reserves[_lp].reserve[1] -= _reserveOut[1] * relativeTokenUpperLimit[reserveAddr[1]]/totalTokenInVaults[1];
        relativeTokenUpperLimit[reserveAddr[0]] -= _reserveOut[0] * relativeTokenUpperLimit[reserveAddr[0]] / totalTokenInVaults[0];
        relativeTokenUpperLimit[reserveAddr[1]] -= _reserveOut[1] * relativeTokenUpperLimit[reserveAddr[1]] / totalTokenInVaults[1];
        reserves[_lp].totalSupply -= _lpDel;
        emit DereaseLpAmount(_lp, _reserveOut, _lpDel);
    }

    function lpSettings(address _lp, uint32 _balanceFee, uint _a0) public onlyLpManager{
        require(_balanceFee <= 500,"World Swap Vaults: balance fee cant > 5%");
        reserves[_lp].balanceFee =_balanceFee;
        reserves[_lp].a0 = _a0;
        emit LpSettings(_lp, _balanceFee, _a0) ;
    }
    function addTokenApproveToLpManager(address _token) public onlyLpManager{     
        IERC20(_token).approve(lpManager, type(uint256).max);
    }
    //----------------------------------------Parameters Function------------------------------

    function lengthOfPairsInVault() public view returns (uint) {
        return (allPairsInVault.length);
    }
    function getLpReserve(address _lp) public view returns (uint[2] memory ,uint[2] memory, uint ) {
        require(_lp!=address(0),"World Swap Vaults: cant be 0 address");
        address[2] memory reserveAddr = getLpPair( _lp) ;
        uint[2] memory TokenInVaults;
        if(reserveAddr[0]==address(0)){
            return (TokenInVaults, reserves[_lp].priceCumulative, reserves[_lp].totalSupply);
        }
        if(relativeTokenUpperLimit[reserveAddr[0]] == 0){
            TokenInVaults[0] = 0;
            TokenInVaults[1] = 0;
        }else{
            TokenInVaults[0] = reserves[_lp].reserve[0] * IERC20(reserveAddr[0]).balanceOf(address(this)) / relativeTokenUpperLimit[reserveAddr[0]];
            TokenInVaults[1] = reserves[_lp].reserve[1] * IERC20(reserveAddr[1]).balanceOf(address(this)) / relativeTokenUpperLimit[reserveAddr[1]];
        }
                
        return (TokenInVaults, reserves[_lp].priceCumulative, reserves[_lp].totalSupply);
    }

    function getLpTokenSum(address _lp) public view returns (uint[2] memory totalTokenInVaults){
        address[2] memory reserveAddr = getLpPair( _lp) ;
        totalTokenInVaults[0] = IERC20(reserveAddr[0]).balanceOf(address(this));
        totalTokenInVaults[1] = IERC20(reserveAddr[1]).balanceOf(address(this));
    }

    function getLpPrice(address _lp) public view returns (uint price){
        require(_lp!=address(0),"World Swap Vaults: cant be 0 address");
        if(reserves[_lp].priceCumulative[1] == 0){
            price = 1 ether;
        }else{
            price = reserves[_lp].priceCumulative[0]* 1 ether/reserves[_lp].priceCumulative[1];
        }
    }
    function getLpPair(address _lp) public view returns (address[2] memory){
        return reserves[_lp].assetAddr;
    }
    function getLpInputTokenSlot(address _lp,address _inputToken) public view returns (bool slot){
        if(_inputToken == reserves[_lp].assetAddr[0]){
            slot = true;
        }else{
            slot = false;
        }
    }
    function getLpSettings(address _lp) external view returns(uint32 balanceFee, uint a0){
        balanceFee = reserves[_lp].balanceFee;
        a0 = reserves[_lp].a0;
    }
    //----------------------------------------Exchange Function------------------------------
    function exchange(structlibrary.exVaults memory _exVaults,uint deadline) public lock returns(uint){
        require(_exVaults.tokens[0]!=_exVaults.tokens[1],"World Swap Vaults: can't swap same token");
        uint inputAmount;
        uint outputAmount;
        uint plusAmount;
        uint tempAmount;
        uint tempAmount0;
        uint tempAmount1;
        inputAmount = IERC20(_exVaults.tokens[0]).balanceOf(address(this));
        outputAmount = IERC20(_exVaults.tokens[1]).balanceOf(address(this));
        
        IERC20(_exVaults.tokens[0]).safeTransferFrom(msg.sender,address(this),_exVaults.amountIn);
        tempAmount = IERC20(_exVaults.tokens[0]).balanceOf(address(this)) - inputAmount;

        tempAmount0 = inputAmount * getLpPrice(getCoinToStableLpPair[_exVaults.tokens[0]]);
        tempAmount1 = outputAmount * getLpPrice(getCoinToStableLpPair[_exVaults.tokens[1]]);
        if(tempAmount0 > tempAmount1){
            inputAmount = inputAmount * tempAmount1 / tempAmount0;
        }else{
            outputAmount = outputAmount * tempAmount0 / tempAmount1;
        }

        plusAmount = inputAmount * outputAmount;

        outputAmount = (outputAmount - plusAmount / (tempAmount + inputAmount)) * 99 / 100;

        IERC20(_exVaults.tokens[1]).safeTransfer(msg.sender,outputAmount);
        tempAmount = IERC20(_exVaults.tokens[0]).balanceOf(address(this)) * IERC20(_exVaults.tokens[1]).balanceOf(address(this));

        require(tempAmount >= plusAmount,"World Swap Vaults: exceed plus Limits");
        
        return outputAmount;
    }

    function xexchange(address[] memory tokens,uint amountIn,uint amountOut,uint limits,uint deadline) external returns(uint){
        structlibrary.exVaults memory _exVaults;
        _exVaults.tokens = tokens;
        _exVaults.amountIn = amountIn;
        _exVaults.amountOut = amountOut;
        _exVaults.Limits = limits;
        return exchange(_exVaults,deadline);
    }

    // ======================== contract base methods =====================
    
    fallback() external payable {}
    receive() external payable {}

}