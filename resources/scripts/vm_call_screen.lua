--	vm_call_screen.lua
--	LitePBX
--	Version: MPL 1.1
--
--	The contents of this file are subject to the Mozilla Public License Version
--	1.1 (the "License"); you may not use this file except in compliance with
--	the License. You may obtain a copy of the License at
--	http://www.mozilla.org/MPL/
--
--	Software distributed under the License is distributed on an "AS IS" basis,
--	WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License
--	for the specific language governing rights and limitations under the
--	License.
--
--	The Original Code is LitePBX
--
--	Inspired by code created by
--	Mark J Crane <markjcrane@fusionpbx.com>
--	Copyright (C) 2010-2020
--	the FusionPBX Developer.
--
--	Contributor(s):
--	Adrian Fretwell <adrian@litepbx.co.uk>
--
--	call this from the dialplan as a destination with voicemail extension and eavesdrop extension as parameters:
--	<extension name="vm_call_screen" continue="false" uuid="40caf546-e343-404d-9931-0364c7bc7527">
--	    <condition field="destination_number" expression="^6201$">
--		<action application="lua" data="vm_call_screen.lua 201 201"/>
--	    </condition>
--	</extension>


-- set up API object and get parameters
	api = freeswitch.API();
	vm_destination = argv[1];
	ev_destination = argv[2];


-- make sure the session is ready
	if ( session:ready() ) then
		-- answer the call
			session:answer();
		-- get the dialplan variables and set them as local variables
			destination_number = session:getVariable("destination_number");
			domain_name = session:getVariable("domain_name");
			sounds_dir = session:getVariable("sounds_dir");
			rtp_secure_media = session:getVariable("rtp_secure_media");
			caller_id_name = session:getVariable("caller_id_name");
			caller_id_number = session:getVariable("caller_id_number");
			sip_from_user = session:getVariable("sip_from_user");
			mute = session:getVariable("mute");

			call_uuid = session:get_uuid();

		-- set the sounds path for the language, dialect and voice
			default_language = session:getVariable("default_language");
			default_dialect = session:getVariable("default_dialect");
			default_voice = session:getVariable("default_voice");
			if (not default_language) then default_language = 'en'; end
			if (not default_dialect) then default_dialect = 'gb'; end
			if (not default_voice) then default_voice = 'rachael'; end

		-- set rtp_secure_media to an empty string if not provided.
			if (rtp_secure_media == nil) then
				rtp_secure_media = 'false';
			end


		-- set the caller id
			if (caller_id_name) then
				--caller id name provided do nothing
			else
				effective_caller_id_name = session:getVariable("effective_caller_id_name");
				caller_id_name = effective_caller_id_name;
			end

			if (caller_id_number) then
				--caller id number provided do nothing
			else
				effective_caller_id_number = session:getVariable("effective_caller_id_number");
				caller_id_number = effective_caller_id_number;
			end

			if (not vm_destination or vm_destination == "") then
				freeswitch.consoleLog("NOTICE", "[vm_call_screen] vm_destination (argv[1]) is not valid\n");
				session:streamFile(sounds_dir.."/"..default_language.."/"..default_dialect.."/"..default_voice.."/ivr/ivr-invalid_number_format.wav");
				session:hangup("INVALID_NUMBER_FORMAT");
				return;
			end
			if (not ev_destination or ev_destination == "") then
				freeswitch.consoleLog("NOTICE", "[vm_call_screen] ev_destination (argv[2]) is not valid\n");
				session:streamFile(sounds_dir.."/"..default_language.."/"..default_dialect.."/"..default_voice.."/ivr/ivr-invalid_number_format.wav");
				session:hangup("INVALID_NUMBER_FORMAT");
				return;
			end


		-- transfer the call to voicemail
		-- check to see if the user extension exists
			local cmd = "user_exists id ".. vm_destination .." "..domain_name;
			local result = api:executeString(cmd);
			if result == "true" then
				session:execute("transfer", "*99"..vm_destination.." XML "..domain_name);
			else
				freeswitch.consoleLog("NOTICE", "[vm_call_screen] unallocated number transfer "..vm_destination.." XML "..domain_name);
				session:streamFile(sounds_dir.."/"..default_language.."/"..default_dialect.."/"..default_voice.."/ivr/ivr-unallocated_number.wav");
				session:hangup("UNALLOCATED_NUMBER");
				return;
			end

			session:sleep(1000);

		-- Originate call to bridge eavesdrop extension and eavesdrop application
		-- On answer execute bind_meta_app so it will execute an intercept id *5 is pressed
			local cmd = "user_exists id ".. ev_destination .." "..domain_name;
			local result = api:executeString(cmd);
			if result == "true" then
				cmd_string = "bgapi originate {sip_auto_answer=true,sip_h_Alert-Info='Ring Answer',execute_on_answer='bind_meta_app 5 a i transfer::intercept:"..call_uuid.." inline',hangup_after_bridge=false,rtp_secure_media="..rtp_secure_media..",origination_caller_id_name='"..caller_id_name.."',origination_caller_id_number="..caller_id_number..",effective_caller_id_number="..caller_id_number..",effective_caller_id_name='"..caller_id_name.."',caller_destination="..ev_destination.."}user/"..ev_destination.."@"..domain_name.." eavesdrop:"..call_uuid.." inline";
				api:executeString(cmd_string);
			else
				freeswitch.consoleLog("NOTICE", "[vm_call_screen] unallocated number eavesdrop "..ev_destination.."@"..domain_name);
			end
			return;
	end
