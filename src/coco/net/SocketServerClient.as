package coco.net
{
	import coco.data.Message;
	import coco.event.SocketEvent;
	
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.IOErrorEvent;
	import flash.events.ProgressEvent;
	import flash.events.SecurityErrorEvent;
	import flash.events.TimerEvent;
	import flash.net.Socket;
	import flash.utils.ByteArray;
	import flash.utils.Timer;
	
	[Event(name="disconnect", type="coco.event.SocketEvent")]
	
	[Event(name="message", type="coco.event.SocketEvent")]
	
	[Event(name="log", type="coco.event.SocketEvent")]
	
	/**
	 * 服务端的客户端连接 
	 */	
	public class SocketServerClient extends EventDispatcher
	{
		
		private var heartTimer:Timer;
		private var heartChecked:Boolean;
		private var socket:Socket;
		
		public var remoteAddress:String;
		public var remotePort:int;
		
		public function SocketServerClient(c2Socket:Socket)
		{
			socket = c2Socket;
			
			remoteAddress = socket.remoteAddress;
			remotePort = socket.remotePort;
			
			c2Socket.addEventListener(Event.CLOSE, c2Socket_closeHandler);
			c2Socket.addEventListener(ProgressEvent.SOCKET_DATA, c2Socket_dataHandler);
			c2Socket.addEventListener(IOErrorEvent.IO_ERROR, c2Socket_ioErrorHandler);
			c2Socket.addEventListener(SecurityErrorEvent.SECURITY_ERROR, c2Socket_securityErrorHandler);
			
			heartChecked = true;
			heartTimer = new Timer(30000);
			heartTimer.addEventListener(TimerEvent.TIMER, onTimerHandler);
			heartTimer.start();
		}
		
		/**
		 * 关闭连接
		 */		
		public function close():void
		{
			disposeC2Socket(socket);
		}
		
		protected function onTimerHandler(event:TimerEvent):void
		{
			if (!heartChecked)
			{
				log("接收不到客户端心跳 断开");
				disposeC2Socket(socket);
			}
			else
			{
				// 发送心跳
				heartChecked = false;
				var heartMessage:Message = new Message();
				heartMessage.type = "heart";
				send(heartMessage);
			}
		}
		
		private var bufferBytes:ByteArray = new ByteArray();   // 缓冲区字节
		private var packetBytesLength:int = 0;  			   // 包字节长度
		private var packetBytes:ByteArray; 		               // 包字节
		private var processing:Boolean = false;				   // 包处理中
		
		protected function c2Socket_dataHandler(event:ProgressEvent):void
		{
			var c2Socket:Socket = event.currentTarget as Socket;
			while (c2Socket.bytesAvailable)
			{
				c2Socket.readBytes(bufferBytes, bufferBytes.length);
			}
			
			processSocketPacket();
		}
		
		protected function c2Socket_closeHandler(event:Event):void
		{
			disposeC2Socket(socket);
		}
		
		protected function c2Socket_securityErrorHandler(event:SecurityErrorEvent):void
		{
			disposeC2Socket(socket);
		}
		
		protected function c2Socket_ioErrorHandler(event:IOErrorEvent):void
		{
			disposeC2Socket(socket);
		}
		
		private function disposeC2Socket(c2Socket:Socket):void
		{
			if (c2Socket)
			{
				try
				{
					log("客户端已断开: " + remoteAddress + ":" + remotePort);
					
					c2Socket.removeEventListener(Event.CLOSE, c2Socket_closeHandler);
					c2Socket.removeEventListener(ProgressEvent.SOCKET_DATA, c2Socket_dataHandler);
					c2Socket.removeEventListener(IOErrorEvent.IO_ERROR, c2Socket_ioErrorHandler);
					c2Socket.removeEventListener(SecurityErrorEvent.SECURITY_ERROR, c2Socket_securityErrorHandler);
					c2Socket.close();
				} 
				catch(error:Error) 
				{
				}
			}
			
			var ce:SocketEvent = new SocketEvent(SocketEvent.DISCONNECT);
			ce.client = this;
			dispatchEvent(ce);
			
			if (heartTimer)
				heartTimer.stop();
		}
		
		//----------------------------------------------------------------------------------------------------------------
		//
		//  Socket消息包处理部分
		//
		//----------------------------------------------------------------------------------------------------------------
		
		public function processSocketPacket():void
		{
			if (processing) return;
			processing = true;
			
			// 读包头 当前包头等于0 且 缓存中的可读字节数大于包头的字节数才去读
			if (packetBytesLength == 0 && bufferBytes.bytesAvailable >= 8)
			{
				packetBytesLength = int(bufferBytes.readUTFBytes(8));
				packetBytes = new ByteArray();
			}
			
			// 读包内容 只有内容大于包长度的时候才会去读
			if (packetBytesLength > 0 && bufferBytes.bytesAvailable >= packetBytesLength)
			{
				bufferBytes.readBytes(packetBytes, 0, packetBytesLength);
				processPacket(packetBytes);
				
				// 将剩下的字节读取到新的字节组中
				var newBufferBytes:ByteArray = new ByteArray();
				bufferBytes.readBytes(newBufferBytes);
				bufferBytes.clear();
				newBufferBytes.readBytes(bufferBytes);
				newBufferBytes.clear();
				packetBytesLength = 0;
				processing = false;
				
				// 一个包处理完毕 继续处理下一个
				if (bufferBytes.bytesAvailable > 0)
					processSocketPacket();
			}
			else
			{
				processing = false;
			}
		}
		
		private function processPacket(packetData:ByteArray):void
		{
			// 将包的字节流转换成包的json字符串
			var message:String = packetData.readUTFBytes(packetData.bytesAvailable);
			receiveMessage(message);
		}
		
		private function receiveMessage(messageString:String):void
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
				ce.client = this;
				ce.descript = "接收消息";
				
				if (message.type != "heart")
					log("接收到消息: " + messageString);
			} 
			catch(error:Error)
			{
				log("接收到客户端消息: 解析消息包失败," + messageString);
				ce = new SocketEvent(SocketEvent.LOG);
				ce.client = this;
				ce.descript = error.message;
			}
			
			if (ce.message.type == "heart")
			{
				heartChecked = true;
			}
			else
			{
				dispatchEvent(ce);
			}
		}
		
		//----------------------------------------------------------------------------------------------------------------
		//
		//  发送消息
		//
		//----------------------------------------------------------------------------------------------------------------
		
		public function send(message:Message):void
		{
			if (!socket || !socket.connected)
			{
				log("客户端端未连接，无法发送消息");
				return;
			}
			
			var messageJsonString:String = JSON.stringify(message);
			if (message.type != "heart")
				log("给客户端发送消息：" + messageJsonString);
			var messageBytes:ByteArray = new ByteArray();
			messageBytes.writeUTFBytes(messageJsonString);
			
			var packetLength:int = messageBytes.length;
			var packetLengthString:String = packetLength.toString();
			while (packetLengthString.length < 8)
			{
				packetLengthString = "0" + packetLengthString;
			}
			socket.writeUTFBytes(packetLengthString);
			socket.writeBytes(messageBytes);
			socket.flush();
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
				ce.client = this;
				dispatchEvent(ce);
			}
		}
		
	}
}