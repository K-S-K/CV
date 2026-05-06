# SMS Station

[Back to the main page](../../README.md)

**Development period:** 2009-2010.

**Practical application:** Commercial[^1].

## Project purpose. There are two of them

- To create a simple, intuitively understandable desktop SMS-sending manager inspired by the Outlook Express application;
- To create my first .NET / C# application. I read my first book about .NET and C# by Andrew Troelsen in those days.

## The initial requirements of the project

- Application must connect to the user terminal (GSM modem or cell phone);
- Application must be able to send particular SMS, as well as SMS corteges, encoded in PDU form;
- Application must be able to send a particular SMS, as well as message broadcasting;
- Application must have a user-friendly interactive SMS editor;
- Application must provide a possibility to create a recipient library;
- Application must provide a possibility to aggregate recipients into groups;
- Application must provide a clear monitoring of the current state and send a log;
- The application must send messages according to the configured schedule.

**Implementation technologies:** .Net, C#, Windows Forms.

**Developer tools:** Microsoft Visual Studio.

Two things stood out during implementation. PDU encoding revealed a cost that is easy to overlook: Unicode messages carry only 70 characters compared to 140 in ASCII — a direct consequence of encoding every language in a single standard. It made me think about how much is quietly lost when languages multiply. The harder problem was AT command compatibility: different phones and modems interpret the same specification differently. About twenty early users received free licenses because their devices behaved unexpectedly, and they helped to track the difference and test adaptations; the solution was a device dictionary mapping known models to their command variants, with the device-type query as the one command every device agreed on.

The first thing a User must do is to configure and check the connection to the user terminal (cell phone or GSM modem)

![Check terminal](Images/Fig_01_Check_Modem.png)  
Fig. 1. Check terminal connection and functionality

To deal with the broadcasting plan, the user must register recipients in the program.

![Edit the Recipients list](Images/Fig_02_Recipients.png)  
Fig. 2. Edit the Recipients list

It is helpful to aggregate recipients into groups to simplify the broadcasting of common information.

![Check Groups](Images/Fig_03_Check_Groups.png)  
Fig. 3. Check Recipients Groups

The recipient groups must be preliminarily created.

![Edit the Recipients list](Images/Fig_04_Edit_Groups.png)  
Fig. 4. Edit the Recipient Groups

Now, we can edit messages to be sent. In the Message editor, the User can see the total message length,
the amount of partial SMS in the SMS cortege and the amount of letters to fill the current SMS of the cortege.

![Edit a Message](Images/Fig_05_Edit_Message.png)  
Fig. 5. The Message Editor

After that, the User can see and modify the Message sending plan.

![Edit the Recipients list](Images/Fig_06_Sending_Plan.png)  
Fig. 6. The Message sending plan


If the user needs to create a broadcast, they can use the Message broadcast editor.
The messages planned to broadcast are waiting in the message-sending plan
together with individual messages.

![Edit a Message Broadcast](Images/Fig_07_Edit_Broadcast.png)  
Fig. 7. The Message Broadcast Editor

The history of message sending can be seen in the Message log.

![The Message log](Images/Fig_09_Messaging_Log.png)  
Fig. 8. The Message log

[^1]: A couple of dozens of licenses were sold. After that, I found an attractive job and closed this project.
