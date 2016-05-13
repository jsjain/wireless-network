configuration TempTestAppC
{
}
implementation
{
	
	//General components
	components TempTestC as App;
	components MainC, LedsC;
	components new TimerMilliC();
	
	App.Boot -> MainC;
	App.Leds -> LedsC;
	App.Timer -> TimerMilliC;

	components SerialPrintfC;
	components ActiveMessageC;
	components new AMSenderC(AM_RADIO);
	components new AMReceiverC(AM_RADIO);
	components UserButtonC;
	App.ComControl -> ActiveMessageC;
	App.Packet -> AMSenderC;
	App.AMPacket -> AMSenderC;
	App.AMSend -> AMSenderC;
	App.ComControl -> ActiveMessageC;
	App.Get -> UserButtonC.Get;
	App.Notify -> UserButtonC.Notify;
	

}