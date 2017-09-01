package coco.net
{
	import flash.events.Event;
	import flash.events.IEventDispatcher;
	import flash.events.IOErrorEvent;
	import flash.events.ProgressEvent;
	import flash.events.SecurityErrorEvent;
	import flash.events.TimerEvent;
	import flash.net.Socket;
	import flash.system.Security;
	import flash.utils.ByteArray;
	import flash.utils.Timer;
	
	import coco.data.Message;
	import coco.event.SocketEvent;
	
	[Event(name="connect", type="coco.event.SocketEvent")]
	
	[Event(name="disconnect", type="coco.event.SocketEvent")]
	
	[Event(name="message", type="coco.event.SocketEvent")]
	
	[Event(name="log", type="coco.event.SocketEvent")]
	
	/**
	 * 客户端Socket
	 * @author coco
	 */	
	public class SocketClient extends SocketDataProcessor
	{
		public function SocketClient(target:IEventDispatcher=null)
		{
			super(target);
			
			if (instance || !inRightWay)
				throw new Error("Please use C1Connection2.getInstance()");
		}
		
		
		//----------------------------------------------------------------------------------------------------------------
		//
		//  Get Instance
		//
		//----------------------------------------------------------------------------------------------------------------
		
		private static var inRightWay:Boolean = false;
		private static var instance:SocketClient;
		
		public static function getInstance():SocketClient
		{
			inRightWay = true;
			
			if (!instance)
				instance = new SocketClient();
			
			return instance;
		}
		
		
		//----------------------------------------------------------------------------------------------------------------
		//
		//  Variables
		//
		//----------------------------------------------------------------------------------------------------------------
		
		public function get connected():Boolean
		{
			return c2Socket && c2Socket.connected;
		}
		
		//----------------------------------------------------------------------------------------------------------------
		//
		//  Methods
		//
		//----------------------------------------------------------------------------------------------------------------
		
		private var serverHost:String;
		private var c2Socket:Socket;
		private var checkTimer:Timer;
		private var currentPolicyPort:int;
		private var currentPort:int;
		
		public function init(host:String = "localhost", 
							 port:int = 12016, 
							 policyPort:int = 12015):void
		{
			currentPort = port;
			currentPolicyPort = policyPort;
			
			// 30s检查一次连接情况
			checkTimer = new Timer(30000);
			checkTimer.addEventListener(TimerEvent.TIMER, checkTimer_timerHandler);
			checkTimer.start();
			
			serverHost = host;
			
			tryLogin();
		}
		
		public function dispose():void
		{
			checkTimer.removeEventListener(TimerEvent.TIMER, checkTimer_timerHandler);
			checkTimer.stop();
			checkTimer = null;
			
			disposeC2Socket();
		}
		
		private function tryLogin():void
		{
			if (!connected)
			{
				initC2Socket();
				log("开始加载策略文件..." + serverHost + ":" + currentPolicyPort);
				Security.loadPolicyFile("xmlsocket://" + serverHost + ":" + currentPolicyPort);
				log("开始连接服务端服务..." + serverHost + ":" + currentPort);
				c2Socket.connect(serverHost, currentPort);
			}
		}
		
		private function checkTimer_timerHandler(e:TimerEvent):void
		{
			if (!connected)
			{
				log("检测到服务端已断开...尝试重新连接");
				tryLogin();
			}
		}
		
		private function initC2Socket():void
		{
			if (!c2Socket)
			{
				c2Socket = new Socket();
				c2Socket.addEventListener(Event.CLOSE, c2Socket_closeHandler);
				c2Socket.addEventListener(ProgressEvent.SOCKET_DATA, c2Socket_dataHandler);
				c2Socket.addEventListener(Event.CONNECT, c2Socket_connectHandler);
				c2Socket.addEventListener(IOErrorEvent.IO_ERROR, c2Socket_ioErrorHandler);
				c2Socket.addEventListener(SecurityErrorEvent.SECURITY_ERROR, c2Socket_securityErrorHandler);
			}
		}
		
		private function disposeC2Socket():void
		{
			if (c2Socket)
			{
				try
				{
					c2Socket.removeEventListener(Event.CLOSE, c2Socket_closeHandler);
					c2Socket.removeEventListener(ProgressEvent.SOCKET_DATA, c2Socket_dataHandler);
					c2Socket.removeEventListener(Event.CONNECT, c2Socket_connectHandler);
					c2Socket.removeEventListener(IOErrorEvent.IO_ERROR, c2Socket_ioErrorHandler);
					c2Socket.removeEventListener(SecurityErrorEvent.SECURITY_ERROR, c2Socket_securityErrorHandler);
					c2Socket.close();
					c2Socket = null;
					//					log("释放C2Socket成功");
				} 
				catch(error:Error) 
				{
					//					log("释放C2Socket失败" + error.message);
				}
			}
		}
		
		protected function c2Socket_connectHandler(event:Event):void
		{
			log("服务端已连接");
			var ce:SocketEvent = new SocketEvent(SocketEvent.CONNECT);
			dispatchEvent(ce);
		}
		
		protected function c2Socket_dataHandler(event:ProgressEvent):void
		{
			while (c2Socket.bytesAvailable)
			{
				c2Socket.readBytes(bufferBytes, bufferBytes.length);
			}
			processSocketPacket();
		}
		
		protected function c2Socket_closeHandler(event:Event):void
		{
			// 释放socket
			disposeC2Socket();
			
			log("服务端已断开");
			var ce:SocketEvent = new SocketEvent(SocketEvent.DISCONNECT);
			dispatchEvent(ce);
		}
		
		protected function c2Socket_securityErrorHandler(event:SecurityErrorEvent):void
		{
			// 释放socket
			disposeC2Socket();
			log("安全错误" + event.text);
		}
		
		protected function c2Socket_ioErrorHandler(event:IOErrorEvent):void
		{
			// 释放socket
			disposeC2Socket();
			log("IO错误 " + event.text);
		}
		
		//----------------------------------------------------------------------------------------------------------------
		//
		//  日志输出
		//
		//----------------------------------------------------------------------------------------------------------------
		
		private function log(...args):void
		{
			var arg:Array = args as Array;
			if (arg.length > 0)
			{
				arg[0] = "[Socket通信服务] " + arg[0];
				var ce:SocketEvent = new SocketEvent(SocketEvent.LOG);
				ce.descript = args.join(" ");
				dispatchEvent(ce);
			}
		}
		
		
		//----------------------------------------------------------------------------------------------------------------
		//
		//  Socket消息包处理部分
		//
		//----------------------------------------------------------------------------------------------------------------
		
		override protected function receiveMessage(messageString:String):void
		{
			var ce:SocketEvent;
			try
			{
				// 将json字符串 转换为消息
				//	Message
				//		type
				//		content
				var messageObject:Object = JSON.parse(messageString);
				var message:Message = new Message();
				message.type = messageObject.type;
				message.content = messageObject.content;
				
				ce = new SocketEvent(SocketEvent.MESSAGE);
				ce.message = message;
				ce.descript = "接收消息";
				
				if (message.type != "heart")
					log("接收到服务端消息: " + messageString);
			} 
			catch(error:Error)
			{
				log("解析消息包失败 " + message);
				ce = new SocketEvent(SocketEvent.LOG);
				ce.descript = error.message;
			}
			
			if (ce.message.type == "heart")
			{
				var heartMessage:Message = new Message();
				heartMessage.type = "heart";
				send(heartMessage);
			}
			else
				dispatchEvent(ce);
		}
		
		/**
		 * 发送消息 
		 * @param message
		 */		
		public function send(message:Message):void
		{
			if (!c2Socket || !c2Socket.connected)
			{
				log("服务端未连接，无法发送消息");
				return;
			}
			
			var messageJsonString:String = JSON.stringify(message);
			if (message.type != "heart")
				log("给服务端发送消息：" + messageJsonString);
			var messageBytes:ByteArray = new ByteArray();
			messageBytes.writeUTFBytes(messageJsonString);
			
			var packetLength:int = messageBytes.length;
			var packetLengthString:String = packetLength.toString();
			while (packetLengthString.length < 8)
			{
				packetLengthString = "0" + packetLengthString;
			}
			c2Socket.writeUTFBytes(packetLengthString);
			c2Socket.writeBytes(messageBytes);
			c2Socket.flush();
		}
		
	}
}