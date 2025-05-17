// SPDX-License-Identifier: Business Source License 1.1
// First Release Time : 2025.05.18
pragma solidity 0.8.6;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import "./interfaces/ixvaults.sol";

contract worldPublicSwapPair is ERC20 {
    
    //----------------------Persistent Variables ----------------------
    string public constant NAME = 'World Swap LIQUIDITY';
    uint public constant MINIMUM_LIQUIDITY = 10**3;
    bytes4 private constant SELECTOR = bytes4(keccak256(bytes('transfer(address,uint256)')));
    
    uint8   public lpCategory;
    address public factory;
    address public token0;
    address public token1;
    address public vaults;
    address public slc;
    address public lpManager;

    //--------------------------for permit use-----------------------------

    bytes32 public DOMAIN_SEPARATOR;
    // keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
    bytes32 public constant PERMIT_TYPEHASH = 0x6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c9;
    mapping(address => uint) public nonces;

    //----------------------------modifier ----------------------------
    uint private unlocked = 1;
    modifier lock() {
        require(unlocked == 1, 'World Swap Pair: LOCKED');
        unlocked = 0;
        _;
        unlocked = 1;
    }
    modifier onlyLpManager() {
        require(msg.sender == lpManager, 'World Swap Pair: Only Lp Manager Use');
        _;
    }
    
    //----------------------------- event -----------------------------
    event Mint(address indexed mintAddress, uint lpAmount);
    event Burn(address indexed burnAddress, uint lpAmount);
    event Sync(uint32 blockTimestampLast,uint reserve0, uint reserve1);
    //-------------------------- constructor --------------------------
    constructor(string memory _name,string memory _symbol) ERC20(_name, _symbol){
        uint chainId;
        assembly {
            chainId := chainid()
        }
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256('EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)'),
                keccak256(bytes(NAME)),
                keccak256(bytes('1')),
                chainId,
                address(this)
            )
        );
        factory = msg.sender;
    }
    //-------------------------- initialize --------------------------
    // called once by the factory at time of deployment
    // lpCategory = 1 -> Base
    // lpCategory = 2 -> Expand
    function initialize(address _token0,
                        address _token1,
                        address _vaults,
                        address _slc,
                        address _lpManager
                        ) external {
        require(msg.sender == factory, 'World Swap Pair: FORBIDDEN'); // sufficient check
        token0 = _token0;
        token1 = _token1;
        vaults = _vaults;
        lpManager = _lpManager;
        if(_token0 == _slc){
            lpCategory = 1;
        }else if(_token1 == _slc){
            lpCategory = 1;
        }else{
            lpCategory = 2;
        }
    }
    //-------------------------- view function --------------------------
    function getReserves() public view returns (uint[2] memory ,uint[2] memory, uint) {
        return ixVaults(vaults).getLpReserve(address(this));
    }
    //-------------------------- sys function --------------------------

    function resetup(address _vaults,address _lpManager) external {
        require(msg.sender == factory, 'World Swap Pair: Only factory could trigger this func.'); // sufficient check
        vaults = _vaults;
        lpManager = _lpManager;
    }

    // --------------------- Mint&Burn function ---------------------
    /**
     * @dev mint lp
     */
    function mintXLp(address _account,uint256 _value) public payable onlyLpManager lock{
        require(_value > 0,"World Swap Pair:Input value MUST > 0");
        _mint(_account, _value);
        emit Mint(_account, _value);
    }
    /**
     * @dev burn lp
     */
    function burnXLp(address _account,uint256 _value) public onlyLpManager lock{
        require(_value > 0,"World Swap Pair:Con't burn 0");
        require(_value <= balanceOf(_account),"World Swap Pair:Must < account balance");
        _burn(_account, _value);
        emit Burn(_account, _value);
    }

    function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external {
        require(deadline >= block.timestamp, 'World Swap Pair: EXPIRED');
        bytes32 digest = keccak256(
            abi.encodePacked(
                '\x19\x01',
                DOMAIN_SEPARATOR,
                keccak256(abi.encode(PERMIT_TYPEHASH, owner, spender, value, nonces[owner]++, deadline))
            )
        );
        address recoveredAddress = ECDSA.recover(digest, v, r, s);
        require(recoveredAddress != address(0) && recoveredAddress == owner, 'World Swap Pair: INVALID_SIGNATURE');
        _approve(owner, spender, value);
    }

}
