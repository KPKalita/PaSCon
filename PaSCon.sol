// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

// PATIENT CONTRACT
contract PatientContract{

    address Owner;

    struct PublicKeys {
        address owner;
        string key;
    }

    mapping (address => PublicKeys) keymaps;

    constructor(string memory publickey) {
        Owner = msg.sender;
        PublicKeys memory pk;
        pk.owner = Owner;
        pk.key = publickey;
        keymaps[pk.owner] = pk;
    }

    modifier only_owner() {
        require(Owner == msg.sender);
        _;
    }

    function get_public_key(address owner) public view returns(string memory){
        return keymaps[owner].key;
    }

    function registration(string memory publickey, address addr) public returns(bool){
        // key gets added in the mapping
        PublicKeys memory pk;
        pk.owner = addr;
        pk.key = publickey;
        keymaps[pk.owner] = pk;
        return true;
    } 

    function initial_share_patient(address addr, uint timestamp, string memory data) public {
        AssistanceContract ac = AssistanceContract(addr);
        ac.initial_share_response(timestamp, data);
    }

    struct EncData {
        address uip;
        address uploader;
        string edata;
        string fields;
        string hash;
        uint epoch; 
        uint timestamp;
        uint rec_num;
    }

    EncData[] list_enc_data;

    uint record_counter = 0;

    // DataStorage Function
    function data_storage(
            address patient_add, 
            string memory edata,
            string memory fields,
            string memory hash) public {

        EncData memory dataStruct;
        dataStruct.uip = patient_add;
        dataStruct.uploader = msg.sender; 
        dataStruct.edata = edata;
        dataStruct.fields = fields;
        dataStruct.hash = hash; 
        dataStruct.epoch = record_counter;
        dataStruct.timestamp = block.timestamp;
        dataStruct.rec_num = record_counter;
        list_enc_data.push(dataStruct);
        record_counter = record_counter + 1;
    }

    function show_enc_data() public view returns(EncData[] memory) {
        return (list_enc_data);
    }

    struct GrantHistory{
        address requester;
        address granter;
        uint timestamp;
        uint req_num;
        uint rec_num;
    }

    GrantHistory[] grant_list;

    // TransferHistory Function
    function transfer_history(
            address requester, 
            address granter, 
            uint req_num, 
            uint rec_num) public {
        GrantHistory memory gh;
        gh.requester = requester;
        gh.granter = granter;
        gh.timestamp = block.timestamp;
        gh.req_num = req_num;
        gh.rec_num = rec_num;
        grant_list.push(gh);
    }

    function show_grant_history() public view returns(GrantHistory[] memory){
        return grant_list;
    }

    function patient_approval(
        address requester,
        address granter,
        string memory ciphertext, 
        uint req_num, 
        uint rec_num, 
        address requester_contract_addr) public only_owner {
        
        AssistanceContract ac = AssistanceContract(requester_contract_addr);
        ac.Patient_Key_Submission(requester, granter, ciphertext, req_num, rec_num);
    }
}

// HEALTH WORKER CONTRACT
contract AssistanceContract {

    address Owner;

    constructor(address addr, string memory public_key) {
        PatientContract pc = PatientContract(addr);
        pc.registration(public_key, msg.sender);
        Owner = msg.sender;
    }

    modifier only_owner() {
        require(Owner == msg.sender);
        _;
    }

    struct Initial_Shares {
        address uploader;
        address patient;
        string data_uploader;
        string data_patient;
        uint timestamp;
    }

    Initial_Shares[] initshare_list;

    function initial_share_request(string memory data) public {
        Initial_Shares memory initshare;
        initshare.uploader = msg.sender;
        initshare.data_uploader = data;
        initshare.timestamp = block.timestamp;
        initshare_list.push(initshare);
    }

    function initial_share_response(uint timestamp, string memory data) public {
        for(uint i=0; i<initshare_list.length; i++){
            if (initshare_list[i].timestamp == timestamp) {
                initshare_list[i].data_patient = data;
                initshare_list[i].patient = msg.sender;
            }
        }

    }

    function show_initial_shares() public view returns(Initial_Shares[] memory){
        return (initshare_list);
    }

    struct Request {
        address requester;
        address granter;
        uint req_num;
        uint rec_num; //  the record number
        bool granted;
    }

    Request[] request_list;

    uint request_counter = 0;

    // AddRequest Function
    function add_request(address addr, uint rec_num) public returns(bool){

        Request memory req;
        req.requester = addr;
        req.granter = Owner;
        req.req_num = request_counter;
        req.granted = false;
        req.rec_num = rec_num;
        request_list.push(req);
        request_counter = request_counter + 1;
        return true;
    }

    // RequestAccess Function
    function request_access(address addr, uint rec_num) public only_owner {
        AssistanceContract ac = AssistanceContract(addr);
        ac.add_request(msg.sender, rec_num);
    }

    struct GrantedKeys{
        address requester;
        address granter;
        string ciphertext_from_granter;
        string ciphertext_from_patient;
        uint req_num;
        uint rec_num;
    }

    GrantedKeys[] granted_keys;

    function show_keys() public view returns(GrantedKeys[] memory){
        return (granted_keys);
    }

    // KeyTransfer Function
    function key_transfer(
        address granter, 
        string memory ciphertext, 
        uint req_num,
        uint rec_num) public returns(bool){

        GrantedKeys memory gk;
        gk.requester = Owner;
        gk.granter = granter;
        gk.ciphertext_from_granter = ciphertext;
        gk.req_num = req_num;
        gk.rec_num = rec_num;
        granted_keys.push(gk);
        return true;
    }

    function request_exist_notgranted(uint num, address requester, uint rec_num) view public returns (bool){
        for (uint i; i< request_list.length;i++){
            if (request_list[i].req_num == num && 
                request_list[i].granted == false &&
                request_list[i].requester == requester &&
                request_list[i].granter == msg.sender &&
                request_list[i].rec_num == rec_num)
                return true;
        }
        return false;
    }

    // GrantAccess Function for granter
    function grant_data_access( 
            address main_contract_addr,
            address requester_contract_addr, 
            address requester, 
            string memory ciphertext, 
            uint req_num,
            uint rec_num) public {

        require(request_exist_notgranted(req_num, requester, rec_num));
        
        AssistanceContract ac = AssistanceContract(requester_contract_addr);
        ac.key_transfer(msg.sender, ciphertext, rec_num, req_num);

        for(uint i=0; i<request_list.length; i++){
            if (request_list[i].req_num == req_num) {
                request_list[i].granted = true;
            }
        }

        PatientContract pc = PatientContract(main_contract_addr);
        pc.transfer_history(requester, msg.sender, req_num, rec_num);
    }

    function Patient_Key_Submission(
        address requester,
        address granter,
        string memory ciphertext,
        uint req_num,
        uint rec_num) public {
            for(uint i=0; i<granted_keys.length; i++){
                if (granted_keys[i].req_num == req_num && 
                    granted_keys[i].rec_num ==  rec_num &&
                    granted_keys[i].requester == requester &&
                    granted_keys[i].granter == granter) {

                    granted_keys[i].ciphertext_from_patient = ciphertext;

                }
            }
        }
}
// END OF THE CODE