package coco.event
{
	import flash.events.Event;
	
	
	/**
	 * FMS服务器事件
	 *  
	 * @author coco
	 * 
	 */	
	public class FMSServerEvent extends Event
	{
		
		/**
		 * 连接FMS服务器成功的时候派发 
		 */		
		public static const CONNECT:String = "fmsServerConnect";
		
		/**
		 * 与FMS服务器断开连接的时候派发 
		 */		
		public static const DISCONNECT:String = "fmsServerDisconnect";
		
		/**
		 * 与FMS服务器连接错误的时候派发
		 */		
		public static const ERROR:String = "fmsServerError";
		
		/**
		 * 收到FMS服务器数据的时候派发 
		 */		
		public static const DATA:String = "fmsServerData";
		
		public function FMSServerEvent(type:String, bubbles:Boolean=false, cancelable:Boolean=false)
		{
			super(type, bubbles, cancelable);
		}
		
		/**
		 * 消息说明 
		 */		
		public var descript:String;
		
	}
}