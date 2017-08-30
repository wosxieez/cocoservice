package coco.event
{
	import flash.events.Event;
	
	import coco.data.Message;
	import coco.net.SocketServerClient;
	
	public class SocketEvent extends Event
	{
		
		/**
		 * 连接成功的时候派发 
		 */		
		public static const CONNECT:String = "connect";
		/**
		 * 断开连接的时候派发 
		 */		
		public static const DISCONNECT:String = "disconnect";
		/**
		 * 收到消息的时候派发 
		 */		
		public static const MESSAGE:String = "message";
		/**
		 * 有日志消息的时候派发 
		 */		
		public static const LOG:String = "log";
		
		public function SocketEvent(type:String, bubbles:Boolean=false, cancelable:Boolean=false)
		{
			super(type, bubbles, cancelable);
		}
		
		public var message:Message;
		
		public var descript:String;
		
		public var client:SocketServerClient;
		
	}
}