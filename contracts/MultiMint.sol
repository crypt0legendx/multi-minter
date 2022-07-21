// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
// import "hardhat/console.sol";

interface NFT {
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    function totalSupply() external view returns (uint256);
}

interface ERC1155 {
  function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes calldata data
    ) external;
}

struct WithdrawData {
    address payable cloneAddress;
    uint256[] tokenIds;
}

struct WithdrawData1155 {
    address payable cloneAddress;
    uint256 tokenId;
    uint256 amount;
}

struct MintParams {
    address saleAddress;
    uint256 nftPrice;
    uint256 maxSupply;

    uint256 clonesAmount;
    uint8 txPerClone;
    uint8 mintPerCall;
    bytes datacall;
}

struct MintDiffParams {
    address saleAddress;
    uint256 nftPrice;
    uint256 maxSupply;
    uint256 clonesAmount;
    uint8 txPerClone;
    uint8 mintPerCall;
    bytes[] datacall;
}

contract MultiMinter is Ownable {
    address payable[] public clones;

    bool initialized;
    address public _owner;

    constructor(
    ) {
        _owner = msg.sender;
    }

    function newClone() internal returns (address payable result) {
        bytes20 targetBytes = bytes20(address(this));

        assembly {
            let clone := mload(0x40)
            mstore(
                clone,
                0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000000000000000000000
            )
            mstore(add(clone, 0x14), targetBytes)
            mstore(
                add(clone, 0x28),
                0x5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000
            )
            result := create(0, clone, 0x37)
        }

        return result;
    }

    function setOwner(address owner) external {
        require(!initialized, "already set");
        _owner = owner;
        initialized = true;
    }

    function addClones(uint256 quantity) public {
        for (uint256 i; i < quantity; i++) {
            address payable clone = newClone();
            clones.push(clone);
            
            MultiMinter(clone).setOwner(address(this));
        }
    }

    function clonesFund(
        uint256 clonesAmount, 
        uint256 nftNumberPerClone,
        uint256 nftPrice
    )
        public
        payable
    {

        require(clones.length >= clonesAmount, "Not enough clones");
        for (uint256 i; i < clonesAmount; i++) {
            clones[i].transfer(nftPrice * nftNumberPerClone);
        }
    }

    function ethBackMain(address payable owner) public {
        require(msg.sender == _owner, "Not owner");
        owner.transfer(address(this).balance);
    }

    function ethBackClones(address payable owner) public onlyOwner {
        for (uint256 i; i < clones.length; i++) {
            MultiMinter(clones[i]).ethBackMain(owner);
        }
    }

    function deployedClonesMint(
        MintParams memory _mintParam
    ) public onlyOwner {
        require(_mintParam.clonesAmount <= clones.length, "Too much clones");
        uint256 totalMint = _mintParam.mintPerCall * _mintParam.txPerClone * _mintParam.clonesAmount;
        uint256 remaining = _mintParam.maxSupply - NFT(_mintParam.saleAddress).totalSupply();

        if (totalMint > remaining) {
           _mintParam.clonesAmount = remaining / (_mintParam.mintPerCall * _mintParam.txPerClone);
        }

        uint256 gasPerEach = 0;
        uint256 startGas = gasleft();

        for (uint256 i; i < _mintParam.clonesAmount; i++) {
            if (gasleft() > gasPerEach) {                   
                _mintCloneInTx(i, _mintParam, true);                
                if(gasPerEach == 0){ //If gasPerEach is not set
                    gasPerEach = startGas - gasleft();
                }
            }
        }        
    }

    function deployedClonesMintPayable(
        MintParams memory _mintParam
    ) public payable {

        require(_mintParam.clonesAmount <= clones.length, "Too much clones");
        uint256 totalMint = _mintParam.mintPerCall * _mintParam.txPerClone * _mintParam.clonesAmount;
        uint256 remaining = _mintParam.maxSupply - NFT(_mintParam.saleAddress).totalSupply();

        if (totalMint > remaining) {
           _mintParam.clonesAmount = remaining / (_mintParam.mintPerCall * _mintParam.txPerClone);
        }

        uint256 gasPerEach = 0;
        uint256 startGas = gasleft();

        for (uint256 i; i < _mintParam.clonesAmount; i++) {
            if (gasleft() > gasPerEach) {                   
                clones[i].transfer(_mintParam.nftPrice * _mintParam.txPerClone * _mintParam.mintPerCall);
                _mintCloneInTx(i, _mintParam, true);                
                if(gasPerEach == 0){ //If gasPerEach is not set
                    gasPerEach = startGas - gasleft();
                }
            }
        }        
        
    }

    function mintWithLoop(
        address saleAddress,
        uint256 nftPrice,
        uint256 maxSupply,

        uint256 _numberOfTokens,
        uint256 _txCount,
        bytes calldata datacall
    ) public payable {
        uint256 totalMint = _numberOfTokens * _txCount;
        uint256 remaining = maxSupply - NFT(saleAddress).totalSupply();        

        if (totalMint > remaining) {
            _txCount = remaining / _numberOfTokens;
        }


        uint256 gasPerEach = 0;
        uint256 startGas = gasleft();
        

        for (uint256 i; i < _txCount; i++) {

            if (gasleft() > gasPerEach) {
                (bool success, bytes memory data) = saleAddress.call{
                    value: nftPrice * _numberOfTokens
                }(datacall);

                
                require(success, "Reverted from sale");
                if(gasPerEach == 0){ //If gasPerEach is not set
                    gasPerEach = startGas - gasleft();
                }

            }
        }
    }

    function createClonesInTx(
        MintParams memory _mintParam
    ) public payable {

        
        require(_mintParam.clonesAmount <= clones.length, "Too much clones");
        uint256 totalMint = _mintParam.mintPerCall * _mintParam.txPerClone * _mintParam.clonesAmount;
        uint256 remaining = _mintParam.maxSupply - NFT(_mintParam.saleAddress).totalSupply();

        if (totalMint > remaining) {
           _mintParam.clonesAmount = remaining / (_mintParam.mintPerCall * _mintParam.txPerClone);
        }

        uint256 gasPerEach = 0;
        uint256 startGas = gasleft();

        for (uint256 i; i < _mintParam.clonesAmount; i++) {
            if (gasleft() > gasPerEach) {                                   
                _mintCloneInTx(i, _mintParam, false);                
                if(gasPerEach == 0){ //If gasPerEach is not set
                    gasPerEach = startGas - gasleft();
                }
            }
        }                 
    }

    function deployedClonesMintDiffData(
        MintDiffParams memory _mintParam
    ) public onlyOwner {
        require(_mintParam.clonesAmount <= clones.length, "Too much clones");
        uint256 totalMint = _mintParam.mintPerCall * _mintParam.txPerClone * _mintParam.clonesAmount;
        uint256 remaining = _mintParam.maxSupply - NFT(_mintParam.saleAddress).totalSupply();

        if (totalMint > remaining) {
            _mintParam.clonesAmount = remaining / (_mintParam.mintPerCall * _mintParam.txPerClone);
        }    

        uint256 gasPerEach = 0;
        uint256 startGas = gasleft();

        for (uint256 i; i < _mintParam.clonesAmount; i++) {
            if (gasleft() > gasPerEach) {         
                _mintCloneDiffInTx(i, _mintParam);                   
                if(gasPerEach == 0){ //If gasPerEach is not set
                    gasPerEach = startGas - gasleft();
                }
            }
        }
    }

    function deployedClonesMintDiffDataPayable(
        MintDiffParams memory _mintParam
    ) public payable {

        require(_mintParam.clonesAmount <= clones.length, "Too much clones");
        uint256 totalMint = _mintParam.mintPerCall * _mintParam.txPerClone * _mintParam.clonesAmount;
        uint256 remaining = _mintParam.maxSupply - NFT(_mintParam.saleAddress).totalSupply();

        if (totalMint > remaining) {
            _mintParam.clonesAmount = remaining / (_mintParam.mintPerCall * _mintParam.txPerClone);
        }

        uint256 gasPerEach = 0;
        uint256 startGas = gasleft();

        for (uint256 i; i < _mintParam.clonesAmount; i++) {
            if (gasleft() > gasPerEach) {         
                clones[i].transfer(_mintParam.nftPrice * _mintParam.txPerClone * _mintParam.mintPerCall);                
                _mintCloneDiffInTx(i, _mintParam);                
                if(gasPerEach == 0){ //If gasPerEach is not set
                    gasPerEach = startGas - gasleft();
                }
            }
        }    
    }

    function _mintCloneDiffInTx(uint256 cloneIndex, MintDiffParams memory _info) private {
        for (uint256 j; j < _info.txPerClone; j++)
            MultiMinter(clones[cloneIndex]).mintClone(
                _info.saleAddress,
                _info.mintPerCall,
                _info.nftPrice,
                _info.datacall[cloneIndex]
            );
    }

    function _mintCloneInTx(uint256 cloneIndex, MintParams memory _info, bool deployed) private {
        
        if(deployed){
            for (uint256 j; j < _info.txPerClone; j++)            
                MultiMinter(clones[cloneIndex]).mintClone(
                    _info.saleAddress,
                    _info.mintPerCall,
                    _info.nftPrice,
                    _info.datacall
                );
                                             
        } else {
            address payable clone = newClone();
            clone.transfer(_info.nftPrice * _info.txPerClone * _info.mintPerCall);  

            for (uint256 j; j < _info.txPerClone; j++)            
                MultiMinter(clone).mintClone(
                    _info.saleAddress,
                    _info.mintPerCall,
                    _info.nftPrice,
                    _info.datacall
                );            
                MultiMinter(clone).setOwner(address(this));
        }   
    }

    function deployedClonesMint1155(
        MintParams memory _mintParam
    ) public onlyOwner {
        require(_mintParam.clonesAmount <= clones.length, "Too much clones");
        uint256 totalMint = _mintParam.mintPerCall * _mintParam.txPerClone * _mintParam.clonesAmount;
        uint256 remaining = _mintParam.maxSupply - NFT(_mintParam.saleAddress).totalSupply();
        uint256 lastClone;
        if (totalMint > remaining) {
            _mintParam.clonesAmount = remaining / (_mintParam.mintPerCall * _mintParam.txPerClone);
            lastClone = remaining % (_mintParam.mintPerCall * _mintParam.txPerClone);
        }

        uint256 gasPerEach = 0;
        uint256 startGas = gasleft();

        for (uint256 i; i < _mintParam.clonesAmount; i++) {
            if (gasleft() > gasPerEach) {   
                _mintCloneInTx(i, _mintParam, true);   
                if(gasPerEach == 0){ //If gasPerEach is not set
                    gasPerEach = startGas - gasleft();
                }
            }         
        }
        if (lastClone > 0 && gasleft() > gasPerEach) {
            if (lastClone / _mintParam.mintPerCall > 0)
                for (uint256 j; j < lastClone / _mintParam.mintPerCall; j++)
                    MultiMinter(clones[_mintParam.clonesAmount]).mintClone(
                        _mintParam.saleAddress,
                        _mintParam.mintPerCall,
                        _mintParam.nftPrice,
                        _mintParam.datacall
                    );
            if (lastClone % _mintParam.mintPerCall > 0)
                MultiMinter(clones[_mintParam.clonesAmount]).mintClone(
                    _mintParam.saleAddress,
                    lastClone % _mintParam.mintPerCall,
                    _mintParam.nftPrice,
                    _mintParam.datacall
                );
        }
    }

    function deployedClonesMintPayable1155(
        MintParams memory _mintParam
    ) public payable {
        require(_mintParam.clonesAmount <= clones.length, "Too much clones");
        uint256 totalMint = _mintParam.mintPerCall * _mintParam.txPerClone * _mintParam.clonesAmount;
        uint256 remaining = _mintParam.maxSupply - NFT(_mintParam.saleAddress).totalSupply();
        uint256 lastClone;
        if (totalMint > remaining) {
            _mintParam.clonesAmount = remaining / (_mintParam.mintPerCall * _mintParam.txPerClone);
            lastClone = remaining % (_mintParam.mintPerCall * _mintParam.txPerClone);
        }

        uint256 gasPerEach = 0;
        uint256 startGas = gasleft();

        for (uint256 i; i < _mintParam.clonesAmount; i++) {
            if (gasleft() > gasPerEach) {   
                clones[i].transfer(_mintParam.nftPrice * _mintParam.txPerClone * _mintParam.mintPerCall);
                _mintCloneInTx(i, _mintParam, true);   
                if(gasPerEach == 0){ //If gasPerEach is not set
                    gasPerEach = startGas - gasleft();
                }
            }         
        }
        if (lastClone > 0 && gasleft() > gasPerEach) {
            clones[_mintParam.clonesAmount].transfer(_mintParam.nftPrice * lastClone);
            if (lastClone / _mintParam.mintPerCall > 0)
                for (uint256 j; j < lastClone / _mintParam.mintPerCall; j++)
                    MultiMinter(clones[_mintParam.clonesAmount]).mintClone(
                        _mintParam.saleAddress,
                        _mintParam.mintPerCall,
                        _mintParam.nftPrice,
                        _mintParam.datacall
                    );
            if (lastClone % _mintParam.mintPerCall > 0)
                MultiMinter(clones[_mintParam.clonesAmount]).mintClone(
                    _mintParam.saleAddress,
                    lastClone % _mintParam.mintPerCall,
                    _mintParam.nftPrice,
                    _mintParam.datacall
                );
        }        
    }

    function deployedClonesMintDiffData1155(
        MintDiffParams memory _mintParam
    ) public onlyOwner {
        require(_mintParam.clonesAmount <= clones.length, "Too much clones");
        uint256 totalMint = _mintParam.mintPerCall * _mintParam.txPerClone * _mintParam.clonesAmount;
        uint256 remaining = _mintParam.maxSupply - NFT(_mintParam.saleAddress).totalSupply();
        uint256 lastClone;

        if (totalMint > remaining) {
            _mintParam.clonesAmount = remaining / (_mintParam.mintPerCall * _mintParam.txPerClone);
            lastClone = remaining % (_mintParam.mintPerCall * _mintParam.txPerClone);
        }    

        uint256 gasPerEach = 0;
        uint256 startGas = gasleft();

        for (uint256 i; i < _mintParam.clonesAmount; i++) {
            if (gasleft() > gasPerEach) {         
                _mintCloneDiffInTx(i, _mintParam);                   
                if(gasPerEach == 0){ //If gasPerEach is not set
                    gasPerEach = startGas - gasleft();
                }
            }
        }

        if (lastClone > 0 && gasleft() > gasPerEach) {
            if (lastClone / _mintParam.mintPerCall > 0)
                for (uint256 j; j < lastClone / _mintParam.mintPerCall; j++)
                    MultiMinter(clones[_mintParam.clonesAmount]).mintClone(
                        _mintParam.saleAddress,
                        _mintParam.mintPerCall,
                        _mintParam.nftPrice,
                        _mintParam.datacall[_mintParam.clonesAmount]
                    );
            if (lastClone % _mintParam.mintPerCall > 0)
                MultiMinter(clones[_mintParam.clonesAmount]).mintClone(
                    _mintParam.saleAddress,
                    lastClone % _mintParam.mintPerCall,
                    _mintParam.nftPrice,
                    _mintParam.datacall[_mintParam.clonesAmount]
                );
        }
    }

    function deployedClonesMintDiffDataPayable1155(
        MintDiffParams memory _mintParam
    ) public payable {

        require(_mintParam.clonesAmount <= clones.length, "Too much clones");
        uint256 totalMint = _mintParam.mintPerCall * _mintParam.txPerClone * _mintParam.clonesAmount;
        uint256 remaining = _mintParam.maxSupply - NFT(_mintParam.saleAddress).totalSupply();
        uint256 lastClone;

        if (totalMint > remaining) {
            _mintParam.clonesAmount = remaining / (_mintParam.mintPerCall * _mintParam.txPerClone);
            lastClone = remaining % (_mintParam.mintPerCall * _mintParam.txPerClone);
        }    

        uint256 gasPerEach = 0;
        uint256 startGas = gasleft();

        for (uint256 i; i < _mintParam.clonesAmount; i++) {
            if (gasleft() > gasPerEach) {       
                clones[i].transfer(_mintParam.nftPrice * _mintParam.txPerClone * _mintParam.mintPerCall);                  
                _mintCloneDiffInTx(i, _mintParam);                   
                if(gasPerEach == 0){ //If gasPerEach is not set
                    gasPerEach = startGas - gasleft();
                }
            }
        }

        if (lastClone > 0 && gasleft() > gasPerEach) {
            clones[_mintParam.clonesAmount].transfer(_mintParam.nftPrice * lastClone);
            if (lastClone / _mintParam.mintPerCall > 0)
                for (uint256 j; j < lastClone / _mintParam.mintPerCall; j++)
                    MultiMinter(clones[_mintParam.clonesAmount]).mintClone(
                        _mintParam.saleAddress,
                        _mintParam.mintPerCall,
                        _mintParam.nftPrice,
                        _mintParam.datacall[_mintParam.clonesAmount]
                    );
            if (lastClone % _mintParam.mintPerCall > 0)
                MultiMinter(clones[_mintParam.clonesAmount]).mintClone(
                    _mintParam.saleAddress,
                    lastClone % _mintParam.mintPerCall,
                    _mintParam.nftPrice,
                    _mintParam.datacall[_mintParam.clonesAmount]
                );
        }   
    }



    function mintClone (
        address sale,
        uint256 _mintPerClone,
        uint256 _nftPrice,
        bytes calldata datacall
    ) public {
    
        (bool success, bytes memory data) = sale.call{
            value: _nftPrice * _mintPerClone
        }(datacall);
        require(success, "Reverted from Sale");
    }

    function getArrayNft(
        WithdrawData[] memory withdrawData,
        address nftContract,
        address to
    ) public onlyOwner {
        for (uint256 i; i < withdrawData.length; i++) {
            MultiMinter(withdrawData[i].cloneAddress).nftWithdrawMain(
                withdrawData[i].tokenIds,
                nftContract,
                to
            );
        }
    }

    function nftWithdrawMain(
        uint256[] memory tokenIds,
        address sale,
        address to
    ) public {
        require(msg.sender == _owner, "Not owner");

        for (uint256 i; i < tokenIds.length; i++) {
            NFT(sale).transferFrom(address(this), to, tokenIds[i]);
        }
    }

    function withdrawMassNft1155(
      WithdrawData1155[] memory withdrawData,
      address nftContract,
      address to
    ) public onlyOwner {
      for (uint256 i; i < withdrawData.length; i++) {
            MultiMinter(withdrawData[i].cloneAddress).withdrawNft1155(
                withdrawData[i].tokenId,
                nftContract,
                to,
                withdrawData[i].amount
            );
        }
    }

    function withdrawNft1155(
        uint256 tokenId,
        address sale,
        address to,
        uint256 amount
    ) public {
        require(msg.sender == _owner, "Not owner");

        ERC1155(sale).safeTransferFrom(address(this), to, tokenId, amount, "0x");
    }

    receive() external payable {}

    function onERC721Received(
        address,
        address,
        uint256,
        bytes memory
    ) public virtual returns (bytes4) {
        // return this.onERC721Received.selector;
        return 0x150b7a02;
    }

    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes calldata
    ) public virtual returns (bytes4) {
      // return this.onERC1155Received.selector;
      return 0xf23a6e61;
    }
}