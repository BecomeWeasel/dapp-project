// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

import "./IRoomShare.sol";

contract RoomShare is IRoomShare {
  uint roomId; // 채번용 방 고유번호
  uint rentId; // 채번용 대여 고유번호
  mapping (uint => Room) internal roomId2room; 
  mapping (address => Rent[]) internal renter2rent;
  mapping (uint => Rent[]) internal roomId2rent; 

  // 추가적으로 룸 땡겨올때 쓰려고 만듬 채번된 방 고유번호 리턴
  function getRoomId() external view returns(uint) {
    return roomId;
  }

  function getRoomByRoomId(uint _roomId) external view returns(Room memory) {
    return roomId2room[_roomId];
  }
  
  function getMyRents() external view override returns(Rent[] memory) {
    return renter2rent[msg.sender];
  }

  function getRoomRentHistory(uint _roomId) external view override returns(Rent[] memory) {
    /* 특정 방의 대여 히스토리를 보여준다. */
    return roomId2rent[_roomId];
  }


  function shareRoom( string calldata name, 
                      string calldata location, 
                      uint price ) external override{
    
    //  * 1. isActive 초기값은 true로 활성화, 함수를 호출한 유저가 방의 소유자이며, 365 크기의 boolean 배열을 생성하여 방 객체를 만든다.
    //  * 2. 방의 id와 방 객체를 매핑한다.
    

    
    // struct Room {
    //   uint id;
    //   string name;
    //   string location;
    //   bool isActive;
    //   uint price;
    //   address owner;
    //   bool[] isRented;
    // }
    
    Room memory newRoom = Room(roomId, name, location, true, price, msg.sender, new bool[](365));
    roomId2room[roomId] = newRoom;

    emit NewRoom(roomId++);
  }

  function rentRoom(uint _roomId, uint year, uint checkInDate, uint checkOutDate) payable external override {
    // /**
    //  * 1. roomId에 해당하는 방을 조회하여 아래와 같은 조건을 만족하는지 체크한다.
    //  *    a. 현재 활성화(isActive) 되어 있는지
    //  *    b. 체크인날짜와 체크아웃날짜 사이에 예약된 날이 있는지 
    //  *    c. 함수를 호출한 유저가 보낸 이더리움 값이 대여한 날에 맞게 지불되었는지(단위는 1 Finney, 10^15 Wei) 
    //  * 2. 방의 소유자에게 값을 지불하고 (msg.value 사용) createRent를 호출한다.
    //  * *** 체크아웃 날짜에는 퇴실하여야하며, 해당일까지 숙박을 이용하려면 체크아웃날짜는 그 다음날로 변경하여야한다. ***
    //  */

    Room memory room = roomId2room[_roomId];

    // 1. roomId에 해당하는 방을 조회하여 아래와 같은 조건을 만족하는지 체크한다.

    // a. 현재 활성화(isActive) 되어 있는지
    // 여기서 require 체크 -> isActive가 false이면 ... throw

    require(room.isActive,"Room not available");

    // b. 체크인날짜와 체크아웃날짜 사이에 예약된 날이 있는지 
    // 여기서 require 체크 -> isRented가 true면 ... throw TODO
    uint i;
    for(i = checkInDate; i < checkOutDate; i++){
      require(!room.isRented[i],"Room already rented");
    }

    // c. 함수를 호출한 유저가 보낸 이더리움 값이 대여한 날에 맞게 지불되었는지(단위는 1 Finney, 10^15 Wei)
    uint256 totalPrice = (checkOutDate - checkInDate) * room.price;
    // 여기서 require 체크 -> 돈이 안맞으면 ... throw 
    require(msg.value==totalPrice*(10**15),"Price not matched");
    
    // 2. 방의 소유자에게 값을 지불하고 (msg.value 사용) createRent를 호출한다.
    _sendFunds(room.owner, msg.value);
    _createRent(_roomId, year, checkInDate, checkOutDate);
    

    // 체크아웃 날짜에는 퇴실하여야하며, 해당일까지 숙박을 이용하려면 체크아웃날짜는 그 다음날로 변경하여야한다. ***


  }

  function _createRent(uint256 _roomId, uint year, uint256 checkInDate, uint256 checkoutDate) internal {
    // /**
    //  * 1. 함수를 호출한 사용자 계정으로 대여 객체를 만들고, 변수 저장 공간에 유의하며 체크인날짜부터 체크아웃날짜에 해당하는 배열 인덱스를 체크한다(초기값은 false이다.).
    //  * 2. 계정과 대여 객체들을 매핑한다. (대여 목록)
    //  * 3. 방 id와 대여 객체들을 매핑한다. (대여 히스토리)
    //  */
    
    Rent memory rent = Rent(rentId, _roomId, year, checkInDate, checkoutDate, msg.sender);

    // 방 렌트되었다고 표시
    // 1. 함수를 호출한 사용자 계정으로 대여 객체를 만들고, 변수 저장 공간에 유의하며 체크인날짜부터 체크아웃날짜에 해당하는 배열 인덱스를 체크한다(초기값은 false이다.).
    for(uint i = checkInDate; i < checkoutDate; i++){
     roomId2room[_roomId].isRented[i] = true;
    }

    // 2. 계정과 대여 객체들을 매핑한다. (대여 목록) 
    // 계정은 msg.sender 로 구분. 함수를 호출한 사용자계정임 ㅇㅇ
    renter2rent[msg.sender].push(rent);
    // 3. 방 id와 대여 객체들을 매핑한다. (대여 히스토리)
    roomId2rent[_roomId].push(rent);

    emit NewRent(_roomId, rentId++);
  }

  function _sendFunds (address owner, uint256 value) internal {
      payable(owner).transfer(value);
  }
  
  

  function recommendDate(uint _roomId, uint checkInDate, uint checkOutDate) external view override returns(uint[2] memory) {
    // /**
    //  * 대여가 이미 진행되어 해당 날짜에 대여가 불가능 할 경우, 
    //  * 기존에 예약된 날짜가 언제부터 언제까지인지 반환한다.
    //  * checkInDate(체크인하려는 날짜) <= 대여된 체크인 날짜 , 대여된 체크아웃 날짜 < checkOutDate(체크아웃하려는 날짜)
    //  */

    // 방객체 가져오고
    Room memory room=roomId2room[_roomId];

    uint[2] memory alreadDate;

    bool found = false;
    for (uint i = checkInDate; i < checkOutDate; i++) {
      // 첫번째에 예약된 날짜를 찾으면
      if (room.isRented[i] == true) {
        if (!found) {
          found = true;
          alreadDate[0] = i;
         }
        alreadDate[1] = i;
       }
     }
     
     return alreadDate; 
  }

    // optional 1
    // caution: 방의 소유자를 먼저 체크해야한다.
    // isActive 필드만 변경한다.
    function markRoomAsInactive(uint256 _roomId) override external{
      // require로 방의 소유자 체크 onwer가 호출자랑 다르면 뱉기
      require(roomId2room[_roomId].owner == msg.sender, "request denied");

      Room storage targetRoom = roomId2room[_roomId];
      targetRoom.isActive = false;
    }

    // optional 2
    // caution: 변수의 저장공간에 유의한다.
    // isRented 필드의 초기화를 진행한다. 
    function initializeRoomShare(uint _roomId) override external{
      Room storage targetRoom=roomId2room[_roomId];


      // 소유자만 초기화 해야함.
      // 소유한 방 중에서 선택한 방의 대여된 일정을 모두 초기화 한다.
      require(roomId2room[_roomId].owner == msg.sender, "request denied");

      uint i;
      for(i = 0; i < 365; i++){
        targetRoom.isRented[i] = false;
      }
    }

}

