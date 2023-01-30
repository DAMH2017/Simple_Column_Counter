
include UNI


$timerPeriod = 400


#########################################################################
# User written helper function.
#
# Returns true if the given character is a number character.
#########################################################################
def isNumber(ch)
	if (ch >= ?0.ord && ch <= ?9.ord)
		return true
	end
	return false
end

#########################################################################
# Sub-device class expected by framework.
#
#########################################################################
class Aux < AuxiliarySubDeviceWrapper
	# Constructor. Call base and do nothing. Make your initialization in the Init function instead.
	def initialize
		super
	end
	
	#########################################################################
	# Method expected by framework.
	#
	# Returns nothing.
	#########################################################################	
	def Init
		#SetLCIsInterpolating(true)
	end
	
end # class Aux





#########################################################################
# Device class expected by framework.
#
# Basic class for access to the chromatography hardware.
# Maintains a set of sub-devices.
# Device represents whole box while sub-device represents particular 
# functional part of chromatography hardware.
# The class name has to be set to "Device" because the device instance
# is created from the C++ code and the "Device" name is expected.
#########################################################################
class Device < DeviceWrapper
	# Constructor. Call base and do nothing. Make your initialization in the Init function instead.
	def initialize
		super
	end
	
	#########################################################################
	# Method expected by framework.
	#
	# Initialize configuration data object of the device and nothing else
	# (set device name, add all sub-devices, setup configuration, set pipe
	# configurations for communication, #  ...).
	# Returns nothing.
	#########################################################################	
	def InitConfiguration
		# Setup configuration.
		Configuration().AddString("Name", "Module Name", "Column Usage", "VerifyName")
		Configuration().AddString("FileDir","File directory",__dir__+"/consumption.txt","")
	end
	
	#########################################################################
	# Method expected by framework.
	#
	# Initialize device. Configuration object is already initialized and filled with previously stored values.
	# (set device name, add all sub-devices, setup configuration, set pipe
	# configurations for communication, #  ...).
	# Returns nothing.
	#########################################################################	
	def Init
		# Initialize members.
		
		@columnHashData=Hash.new
		@columnStringArr=Array.new
		
		#counter to detect the order of running process, this will increase by one in every runing step and print the process
		@processOrder=0
		
		
		#flag when adding new column is true
		@addMode=false
		#flag when editing selected column is true
		@editMode=false
		
		# Device name.
		SetName("Column Usage Counter")
		
		# Set sub-device name.
		@m_Aux=Aux.new
		AddSubDevice(@m_Aux)
		# It is necessary to add item "Name" into configuration prior to its usage here!
		@m_Aux.SetName(Configuration().GetString("Name"))
		
		cFile=Configuration().GetString("FileDir")
		if (!File.exists?(cFile))
			Trace("File not found, creating new file")
			out_file = File.new(cFile, "w+")
			out_file.puts("write your stuff here\n")
			out_file.puts("Column Name\tNumber of injections\n")
			out_file.close
		end
		
		
		
		#Load data from textfile into array
		LoadColumnDataIntoArray(cFile,@columnStringArr)
		
		#Transfer data from array to hashmap
		LoadDataFromArrayToMap(@columnStringArr,@columnHashData)
		
		
		#Add choiceList
		Monitor().AddChoiceList("AvColumns", "Available columns", @columnHashData.length>0 ? @columnHashData.keys[0] : "---","SelectInjNumber")
    	
		#Load ChoiceList data from hashmap
		ReloadChoiceList(@columnHashData,"AvColumns")
		
		#Add Monitor elements
		Monitor().AddString("ColName","Column Name",@columnHashData.length>0 ? Monitor().GetString("AvColumns") : "---","CheckColumnName",true,true)
		Monitor().AddInt("InjNumber","Number of injections",@columnHashData.length>0 ? @columnHashData[Monitor().GetString("AvColumns")] : 0,"",true,true)
		
		Monitor().AddButton("InjResetBtn","Reset injection number","Reset","ResetInjectionNumber")
		Monitor().AddButton("RemoveCol","Remove column","Remove","RemoveColumn")
		Monitor().AddButton("AddCol","Add new column","New","AddColumn")
		Monitor().AddButton("EditCol","Edit column","Edit","EditColumn")
		
		Monitor().AddButton("CancelBtn","","","CancelAddEdit")
		SetTimerPeriod($timerPeriod)
	end
	
	#########################################################################
	# Method Checking
	#
	#Check if column name is more than 32 letters and contains tab
	#########################################################################	
	def CheckColumnName(uiitemcollection,value)
		if(value.length>32)
			return "Column name is too long"
		end
		if (value.include? '\t')
			return "Column name should not contain tabs"
		end
		return true
	end
	#########################################################################
	# Module
	#
	#Enum for detecting if we are in the Add or Edit mode
	#########################################################################
	module MODE
			ADD="Add"
			EDIT="Edit"
	end
	#########################################################################
	# Method Helper
	#
	#Load table data into array
	#########################################################################	
	def LoadColumnDataIntoArray(cFile,array)
		#Load columns data from consumption file
		findTableHeader=false
		f=File.readlines(cFile).each do |line|
			if(findTableHeader)
				line.split(/[\t\n]/).each do |w|
					array.push(w)
				end
			end
			if(line.include? "Number of injections")
				#we reach the table header
				findTableHeader=true
			end
		end
	end
	
	#########################################################################
	# Method Helper
	#
	#Fill Hashmap from array
	#########################################################################	
	def LoadDataFromArrayToMap(array,hash)
		#Create a map to collect column name as key, number of injections as value
		if(array.length>0)
			for i in 0...array.length
				if(i%2==0)
					hash[array[i]]=array[i+1].to_i
				end
			end
		end
	end
	
	#########################################################################
	# Method Helper
	#
	# Reload data from hashmap keys into choiceList 
	#########################################################################	
	def ReloadChoiceList(hash,choiceListRef)
		#update choicelist
			#clear old data of choicelist
		Monitor().ResetChoiceList(choiceListRef)
		    #reloading the data from the updated hashmap
		if(hash.length>0)
			for i in 0...hash.length do
				Monitor().AddChoiceListItem(choiceListRef, hash.keys[i])
			end
		else
			Monitor().AddChoiceListItem(choiceListRef, "---")
		end
	end
	
	#########################################################################
	# Method Helper
	#
	# Reload data from hashmap keys into choiceList 
	#mode is the module value MODE::ADD="Add" or MODE::EDIT="Edit"
	#########################################################################	
	def ModeActive(mode,state)
		Monitor().SetReady(!state)
		stateName=mode=="Add" ? "Adding new column" : "Editing column"
		Monitor().SetStateName(state ? stateName : "Ready")
		#Monitor().SetButtonEnable("InjBtn",!state)
		Monitor().SetButtonEnable("InjResetBtn",!state)
		Monitor().SetButtonEnable("RemoveCol",!state)
		if(mode=="Edit")
			Monitor().SetButtonEnable("AddCol",!state)
		elsif(mode=="Add")
			Monitor().SetButtonEnable("EditCol",!state)
		end
		Monitor().SetButtonEnable("CancelBtn",state)
		if(mode=="Edit")
			Monitor().SetString("EditCol",state ? "Save & Exit" : "Edit")
		elsif(mode=="Add")
			Monitor().SetString("AddCol",state ? "Save & Exit" : "Add")
		end
		Monitor().SetString("CancelBtn",state ? "Cancel" : "")
						
		Monitor().SetReadOnly("ColName",!state)
		Monitor().SetReadOnly("InjNumber",!state)
	end
	
	#########################################################################
	# Method Written
	#
	# Select number of injection when choosing column
	#########################################################################	
	def SelectInjNumber(uiitemcollection,value)
		Monitor().SetString("ColName",value)
		Monitor().SetInt("InjNumber",@columnHashData[value])
		Monitor().Synchronize()
	end
	
	#########################################################################
	# Method Helper
	#
	# Open file, find word, replace
	#########################################################################	
	def OpenFileAndReplace(file,findText,replaceText)
		text = File.read(file)
		puts = text.gsub(findText,replaceText )
		t=File.open(file, "w") { |file| file << puts}
		t.close()
	end
	
		
	#########################################################################
	# Method Written
	#
	# Increase column injection number by 1
	#########################################################################	
	def IncreaseOnInjecting
		selectedColumn=Monitor().GetString("AvColumns")
		#update text file
		file=Configuration().GetString("FileDir")
		findText=selectedColumn+"\t"+(@columnHashData[selectedColumn]).to_s
		replaceText=selectedColumn+"\t"+(@columnHashData[selectedColumn]+1).to_s
		OpenFileAndReplace(file,findText,replaceText)
		#update the monitor
		@columnHashData[selectedColumn]=@columnHashData[selectedColumn]+1
		Monitor().SetInt("InjNumber",@columnHashData[selectedColumn])
	end
	
	#########################################################################
	# Method Written
	#
	# Reset column injection numbers
	#########################################################################	
	def ResetInjectionNumber
		selectedColumn=Monitor().GetString("AvColumns")
		#update text file
		file=Configuration().GetString("FileDir")
		findText=selectedColumn+"\t"+(@columnHashData[selectedColumn]).to_s
		replaceText=selectedColumn+"\t"+(0).to_s
		OpenFileAndReplace(file,findText,replaceText)
		#update the monitor
		@columnHashData[selectedColumn]=0
		Monitor().SetInt("InjNumber",0)
	end
	
	#########################################################################
	# Method Written
	#
	# Remove column from Monitor screen
	#########################################################################	
	def RemoveColumn
		selectedColumn=Monitor().GetString("AvColumns")
		#remove the column line from text file
		file=Configuration().GetString("FileDir")
		findText=selectedColumn+"\t"+(@columnHashData[selectedColumn]).to_s+"\n"
		replaceText=""
		OpenFileAndReplace(file,findText,replaceText) #last line should have \n so it can be removed
		#update the hashmap
		@columnHashData.delete(selectedColumn)
		#update choicelist
		ReloadChoiceList(@columnHashData,"AvColumns")
		#Select last item of the list if choicelist has items other than ---, set in the ColName
		if(@columnHashData.length>0)
			Monitor().SetString("AvColumns",@columnHashData.keys[-1])
			Monitor().SetString("ColName",@columnHashData.keys[-1])
			Monitor().SetInt("InjNumber",@columnHashData.values[-1])
		else
		#Select --- if choicelist has no item, set in the ColName also as ---
			Monitor().SetString("AvColumns","---")
			Monitor().SetString("ColName","---")
			Monitor().SetInt("InjNumber",0)
		end
	end
	
	#########################################################################
	# Method Written
	#
	# Add new column
	#########################################################################	
	def AddColumn
		if(!@addMode)
			@addMode=true
			ModeActive(MODE::ADD,true)
						
			Monitor().SetString("ColName","Column_"+Time.now.to_i.to_s)
			Monitor().SetInt("InjNumber",0)
		else
			@addMode=false
			#enable all buttons
			ModeActive(MODE::ADD,false)
			
			@columnHashData[Monitor().GetString("ColName")]=Monitor().GetInt("InjNumber").to_i
			cFile=Configuration().GetString("FileDir")
			open(cFile, 'a') { |f|
				f.puts Monitor().GetString("ColName")+"\t"+Monitor().GetInt("InjNumber").to_s+"\n"
			}
			#update choicelist
			ReloadChoiceList(@columnHashData,"AvColumns")
			
		    #reloading the data from the updated hashmap
			if(@columnHashData.length>0)
				Monitor().SetString("AvColumns",@columnHashData.keys[-1])
			end
		end
	end
	
	#########################################################################
	# Method Written
	#
	# Update selected column
	#########################################################################	
	def EditColumn
		if(!@editMode)
			@editMode=true
			ModeActive(MODE::EDIT,true)
		else
			@editMode=false
			ModeActive(MODE::EDIT,false)
			
			file=Configuration().GetString("FileDir")
			#this var (findText) should be declared first before updating the hash because it will store the old hash item that will be updated
			findText=Monitor().GetString("AvColumns")+"\t"+(@columnHashData[Monitor().GetString("AvColumns")]).to_s
			#update the hashmap
			@columnHashData[Monitor().GetString("ColName")]=@columnHashData.delete(Monitor().GetString("AvColumns"))
			@columnHashData[Monitor().GetString("ColName")]=Monitor().GetInt("InjNumber")
			#update text file
			replaceText=Monitor().GetString("ColName")+"\t"+Monitor().GetInt("InjNumber").to_s
			OpenFileAndReplace(file,findText,replaceText)
			#update choicelist
			ReloadChoiceList(@columnHashData,"AvColumns")
			
			Monitor().SetString("AvColumns",Monitor().GetString("ColName"))
			
		end
	end
	
	#########################################################################
	# Method Written
	#
	# Cancel adding or editing column
	#########################################################################	
	def CancelAddEdit
		if (@editMode)
			ModeActive(MODE::EDIT,false)
			@editMode=false
		end
		if(@addMode)
			ModeActive(MODE::ADD,false)
			@addMode=false
		end
		Monitor().SetString("ColName",Monitor().GetString("AvColumns"))
		Monitor().SetInt("InjNumber",@columnHashData[Monitor().GetString("ColName")])
	end
	#########################################################################
	# Method expected by framework.
	#
	# Sets communication parameters.
	# Returns nothing.
	#########################################################################	
	def InitCommunication()
	end
	

	
	#########################################################################
	# Method expected by framework
	#
	# Here you should check leading and ending sequence of characters, 
	# check sum, etc. If any error occurred, use ReportError function.
	#	dataArraySent - sent buffer (can be nil, so it has to be checked 
	#						before use if it isn't nil), array of bytes 
	#						(values are in the range <0, 255>).
	#	dataArrayReceived - received buffer, array of bytes 
	#						(values are in the range <0, 255>).
	# Returns true if frame is found otherwise false.		
	#########################################################################	
	def FindFrame(dataArraySent, dataArrayReceived)
		return true
	end
	
	#########################################################################
	# Method expected by framework
	#
	# Return true if received frame (dataArrayReceived) is answer to command
	# sent previously in dataArraySent.
	#	dataArraySent - sent buffer, array of bytes 
	#						(values are in the range <0, 255>).
	#	dataArrayReceived - received buffer, array of bytes 
	#						(values are in the range <0, 255>).
	# Return true if in the received buffer is answer to the command 
	#   from the sent buffer. 
	# Found frames, for which IsItAnswer returns false are processed 
	#  in ParseReceivedFrame
	#########################################################################		
	def IsItAnswer(dataArraySent, dataArrayReceived)
		# Check received data length.
		return true 
	end
	
	#########################################################################
	# Method expected by framework
	#
	# Returns serial number string from HW (to comply with CFR21) when 
	# succeessful otherwise false or nil. If not supported return false or nil.
	#########################################################################	
	def CmdGetSN
		return false
	end
	
	#########################################################################
	# Method expected by framework.
	#
	# gets called when instrument opens
	# Returns true when successful otherwise false.
	#########################################################################
	def CmdOpenInstrument
		# Nothing to send.
		return true
	end
	
	#########################################################################
	# Method expected by framework.
	#
	# gets called when sequence starts
	# Returns true when successful otherwise false.
	#########################################################################
	def CmdStartSequence
		# Nothing to send.
		@processOrder+=1
		Trace("Step "+@processOrder.to_s+" CmdStartSequence runs")
		return true
	end
	
	#########################################################################
	# Method expected by framework.
	#
	# gets called when sequence resumes
	# Returns true when successful otherwise false.
	#########################################################################
	def CmdResumeSequence
		# Nothing to send.
		@processOrder+=1
		Trace("Step "+@processOrder.to_s+" CmdResumeSequence runs")
		return true
	end
	
	#########################################################################
	# Method expected by framework.
	#
	# gets called when run starts
	# Returns true when successful otherwise false.
	#########################################################################
	def CmdStartRun
		# Nothing to send.
		IncreaseOnInjecting()
		@processOrder+=1
		Trace("Step "+@processOrder.to_s+" CmdStartRun runs")
		return true
	end
	
	#########################################################################
	# Method expected by framework.
	#
	# gets called when injection performed
	# Returns true when successful otherwise false.
	#########################################################################
	def CmdPerformInjection
		# Nothing to send.
		@processOrder+=1
		Trace("Step "+@processOrder.to_s+" CmdPerformInjection runs")
		return true
	end
	
	#########################################################################
	# Method expected by framework.
	#
	# gets called when injection bypassed
	# Returns true when successful otherwise false.
	#########################################################################
	def CmdByPassInjection
		# Nothing to send.
		@processOrder+=1
		Trace("Step "+@processOrder.to_s+" CmdByPassInjection runs")
		return true
	end
	
	#########################################################################
	# Method expected by framework.
	#
	# Starts method in HW.
	# Returns true when successful otherwise false.
	#########################################################################
	def CmdStartAcquisition
		Monitor().SetRunning(true)
		# Command formatter.
		@processOrder+=1
		Trace("Step "+@processOrder.to_s+" CmdStartAcquisition runs")
		return true
	end
	
	#########################################################################
	# Method expected by framework.
	#
	# gets called when acquisition restarts
	# Returns true when successful otherwise false.
	#########################################################################
	def CmdRestartAcquisition
		# Nothing to send.
		return true
	end	

	#########################################################################
	# Method expected by framework.
	#
	# Stops running method in hardware. 
	# Returns true when successful otherwise false.	
	#########################################################################
	def CmdStopAcquisition
		#Monitor().SetRunning(false)
		return true
	end	
	
	#########################################################################
	# Method expected by framework.
	#
	# Aborts running method or current operation. Sets initial state.
	# Returns true when successful otherwise false.	
	#########################################################################
	def CmdAbortRunError
		Monitor().SetRunning(false)
		return true
	end
	
	#########################################################################
	# Method expected by framework.
	#
	# Aborts running method or current operation (request from user). Sets initial state.
	# Returns true when successful otherwise false.
	#########################################################################
	def CmdAbortRunUser
		Monitor().SetRunning(false)
		return true
	end
	
	#########################################################################
	# Method expected by framework.
	#
	# Aborts running method or current operation (shutdown). Sets initial state.
	# Returns true when successful otherwise false.	
	#########################################################################
	def CmdShutDown
		CmdAbortRunError()
		return true
	end
	
	#########################################################################
	# Method expected by framework.
	#
	# gets called when run stops
	# Returns true when successful otherwise false.
	#########################################################################
	def CmdStopRun
		Monitor().SetRunning(false)
		# Nothing to send.
		return true
	end
	
	#########################################################################
	# Method expected by framework.
	#
	# gets called when sequence stops
	# Returns true when successful otherwise false.
	#########################################################################
	def CmdStopSequence
		# Nothing to send.
		return true
	end
	
	#########################################################################
	# Method expected by framework.
	#
	# gets called when closing instrument
	# Returns true when successful otherwise false.
	#########################################################################
	def CmdCloseInstrument
		# Nothing to send.
		return true
	end	
	
	#########################################################################
	# Method expected by framework.
	#
	# Tests whether hardware device is present on the other end of the communication line.
	# Send some simple command with fast response and check, whether it has made it
	# through pipe and back successfully.
	# Returns true when successful otherwise false.
	#########################################################################
	def CmdTestConnect
		return true
	end
		
	#########################################################################
	# Method expected by framework.
	#
	# Send method to hardware.
	# Returns true when successful otherwise false.	
	#########################################################################
	def CmdSendMethod()
		@processOrder+=1
		Trace("Step "+@processOrder.to_s+" CmdSendMethod runs")
		return true		
	end
	
	#########################################################################
	# Method expected by framework.
	#
	# Loads method from hardware.
	# Returns true when successful otherwise false.	
	#########################################################################
	def CmdLoadMethod(method)
		@processOrder+=1
		Trace("Step "+@processOrder.to_s+" CmdLoadMethod runs")
		return true		
	end
		
	#########################################################################
	# Method expected by framework.
	#
	# Duration of LC method.
	# Returns complete (from start of acquisition) length (in minutes) 
	# 	of the current method in sub-device (can use GetRunLengthTime()).
	# Returns METHOD_FINISHED when hardware instrument is not to be waited for or 
	# 	method is not implemented.
	# Returns METHOD_IN_PROCESS when hardware instrument currently processes 
	# 	the method and sub-device cannot tell how long it will take.
	#########################################################################
	def GetMethodLength
		return METHOD_FINISHED
	end	
	
	
	#########################################################################
	# Method expected by framework.
	#
	# Periodically called function which should update state 
	# of the sub-device and monitor.
	# Returns true when successful otherwise false.	
	#########################################################################
	def CmdTimer
		Monitor().Synchronize()
				
		if(!Monitor().IsRunning())
			if(Monitor().GetChoiceListItemCount("AvColumns")<2 && Monitor().GetString("AvColumns")=="---")
				Monitor().SetReady(false)
			end
			return false
		end
		
		if(Monitor().IsRunning())
			#Monitor().SetButtonEnable("InjBtn",false)
			Monitor().SetButtonEnable("InjResetBtn",false)
			Monitor().SetButtonEnable("AddCol",false)
			Monitor().SetButtonEnable("InjResetBtn",false)
		end
		
		return true
	end

	#########################################################################
	# Method expected by framework
	#
	# gets called when user presses autodetect button in configuration dialog box
	# return true, false or error message (equals to false)
	#########################################################################
	def CmdAutoDetect
		return CmdTestConnect()
	end
	
	#########################################################################
	# Method expected by framework
	#
	# Processes unrequested data sent by hardware. 
	#	dataArrayReceived - received buffer, array of bytes 
	#						(values are in the range <0, 255>).
	# Returns true if frame was processed otherwise false.
	# The frame found by FindFrame can be processed here if 
	#  IsItAnswer returns false for it.
	#########################################################################
	def ParseReceivedFrame(dataArrayReceived)
		# Passes received frame to appropriate sub-device's ParseReceivedFrame function.
	end
	
	#########################################################################
	# User written method.
	#
	# Validates length of LC name.
	# Validation function returns true when validation is successful otherwise
	# it returns message which will be shown in the Message box.	
	#########################################################################
	def VerifyName(uiitemcollection,value)
		if (value.length >= 32)
			return "Name too long"
		end
		return true
	end

	#########################################################################
	# Required by Framework
	#
	# Gets called when chromatogram is acquired, chromatogram might not exist at the time.
	#########################################################################
	def NotifyChromatogramFileName(chromatogramFileName)
	end
	
	#########################################################################
	# Required by Framework
	#
	# Validates whole method. Use method parameter and NOT object returned by Method(). 
	# There is no need to validate again attributes validated somewhere else.
	# Validation function returns true when validation is successful otherwise
	# it returns message which will be shown in the Message box.	
	#########################################################################
	def CheckMethod(situation,method)
		return true
	end

	def OnEsStopSingle_StopSeq()
		ReportError(EsStopSingle_StopSeq,"Test EsStopSingle_StopSeq")
	end

end # class Device


