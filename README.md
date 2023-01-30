# Simple Column Counter
This script was test on Clarity Version 8.8 but it will work with older versions.

## How to use
1-	Open Clarity_Demo, click on (Configuration).
 ![image](https://user-images.githubusercontent.com/25401184/215547056-0646c7d8-ed90-4b0a-bda2-aa6150bce5f8.png)

2-	Press(Add), Select UniRuby script, load the script (Simple Column Usage Counter.rb), change the name of the module as needed, you can change the file name and its directory which is by default the current directory and file name (Consumption.txt), after finish click OK.
 ![image](https://user-images.githubusercontent.com/25401184/215547093-138ac41e-40ba-454b-a98d-064522c6a395.png)
![image](https://user-images.githubusercontent.com/25401184/215547168-a2124e6a-95ac-4ee9-ba74-91084d4367e2.png)
![image](https://user-images.githubusercontent.com/25401184/215547221-898d4699-a6cf-4ff7-b00e-132c4f9ae014.png)

3-	Now import the script into your module (GC, HPLC,….), then press OK.
![image](https://user-images.githubusercontent.com/25401184/215547271-310146d0-d834-4aa5-9b79-cfc1cc0b5140.png)

4-	Click on the instrument, go to (Monitor) screen, scroll down to (Column Usage Counter), for now the device is not ready until you add at least one column.
5-	Click on (New) to add new column, edit the name and number of injections, then click (Save & Exit), now the new column is added into the created text file, the device is ready.
6-	To edit an existed column, select the column from the drop down list of added columns, click (Edit), change the name and number of injections, then click (Save & Exit).
7-	To reset the number of injections, select the column from drop down list and click (Reset).
8-	To remove the column, select the column from drop down list and click (Delete).
 ![image](https://user-images.githubusercontent.com/25401184/215547324-388b07a3-151f-4d9c-aa30-18b88f6b6270.png)

9-	When press (Run), the number of injections of selected column will increase by one, edit the text file with the new injection count.
