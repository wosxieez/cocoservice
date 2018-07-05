package coco.net
{
	import flash.events.AsyncErrorEvent;
	import flash.events.EventDispatcher;
	import flash.events.IOErrorEvent;
	import flash.events.NetStatusEvent;
	import flash.events.SecurityErrorEvent;
	import flash.media.Camera;
	import flash.media.Microphone;
	import flash.media.VideoStreamSettings;
	import flash.net.NetConnection;
	import flash.net.NetStream;
	
	import coco.event.FMSServerEvent;
	
	[Event(name="fmsServerConnect", type="coco.event.FMSServerEvent")]
	
	[Event(name="fmsServerDisconnect", type="coco.event.FMSServerEvent")]
	
	[Event(name="fmsServerError", type="coco.event.FMSServerEvent")]
	
	[Event(name="fmsServerData", type="coco.event.FMSServerEvent")]
	
	/**
	 *
	 * FMS服务器 连接类
	 *  
	 * @author coco
	 * 
	 */	
	public class FMSServerService extends EventDispatcher
	{
		
		public function FMSServerService()
		{
		}
		
		//--------------------------------------------------------------------------
		//
		//  Get Instance
		//
		//--------------------------------------------------------------------------
		
		private static var instance:FMSServerService;
		
		public static function getInstance():FMSServerService
		{
			if (!instance)
				instance = new FMSServerService();
			
			return instance;
		}
		
		
		//--------------------------------------------------------------------------
		//
		//  Variables
		//
		//--------------------------------------------------------------------------
		
		private var netConnection:NetConnection;
		
		private var outstream:NetStream; // must class var
		private var instream:NetStream; // must class var
		
		/**
		 * FMS服务器连接状态
		 * @return 
		 */		
		public function get connected():Boolean
		{
			return netConnection && netConnection.connected;
		}
		
		//--------------------------------------------------------------------------
		//
		//  Methods
		//
		//--------------------------------------------------------------------------
		
		/**
		 * 连接FMS服务器
		 *  
		 * @param url 视频流服务地址
		 * 
		 */		
		public function connect(url:String):void
		{
			clearConnection(netConnection); 
			netConnection = new NetConnection();
			netConnection.client = new FMSClient("netConnection");
			addConnectionHandler(netConnection);
			netConnection.connect(url);
		}
		
		/**
		 *	断开与FMS服务器的连接 
		 */		
		public function disconnect():void
		{
			if (netConnection && netConnection.connected)
				netConnection.close();
		}
		
		/**
		 * 
		 * 发布视频或音频
		 * 
		 * @param name
		 * @param type
		 * @param camera
		 * @param microphone
		 * 
		 */		
		public function send(name:String, 
							 camera:Camera = null, 
							 microphone:Microphone = null,
							 videoStreamSettings:VideoStreamSettings = null,
							 type:String = "live"):NetStream
		{
			if (!netConnection || !netConnection.connected)
			{
				var fse:FMSServerEvent;
				fse = new FMSServerEvent(FMSServerEvent.ERROR)
				fse.descript = "发送失败，FMS服务器未连接";
				dispatchEvent(fse);
				return null;
			}
			
			outstream = new NetStream(netConnection);
			if (camera)
				outstream.attachCamera(camera);
			if (microphone)
				outstream.attachAudio(microphone);
			if (videoStreamSettings)
				outstream.videoStreamSettings = videoStreamSettings;
			outstream.client = new FMSClient("outstream " + name);
			outstream.addEventListener(NetStatusEvent.NET_STATUS, connection_netStatusHandler);
			outstream.publish(name, type);
			return outstream;
		}
		
		/**
		 * 接收指定名称的流
		 * 
		 * @param name
		 * @return 
		 */		
		public function receive(name:String):NetStream
		{
			if (!netConnection || !netConnection.connected)
			{
				var fse:FMSServerEvent;
				fse = new FMSServerEvent(FMSServerEvent.ERROR)
				fse.descript = "接收失败，FMS服务器未连接";
				dispatchEvent(fse);
				return null;
			}
			
			instream = new NetStream(netConnection);
			instream.client = new FMSClient("instream " + name);
			instream.play(name);
			
			return instream;
		}
		
		/**
		 *
		 * 添加connection事件
		 *  
		 * @param connection
		 * 
		 */		
		private function addConnectionHandler(connection:NetConnection):void
		{
			if (connection)
			{
				connection.addEventListener(NetStatusEvent.NET_STATUS, connection_netStatusHandler);
				connection.addEventListener(AsyncErrorEvent.ASYNC_ERROR,connection_asyncErrorHandler);
				connection.addEventListener(IOErrorEvent.IO_ERROR, connection_ioErrorHandler);
				connection.addEventListener(SecurityErrorEvent.SECURITY_ERROR, connection_netSecurityErrorHandler);
			}
		}
		
		/**
		 * 
		 * 移除Connection
		 *  
		 * @param connection
		 * 
		 */		
		private function clearConnection(connection:NetConnection):void
		{
			if (connection)
			{
				connection.removeEventListener(NetStatusEvent.NET_STATUS, connection_netStatusHandler);
				connection.removeEventListener(AsyncErrorEvent.ASYNC_ERROR,connection_asyncErrorHandler);
				connection.removeEventListener(IOErrorEvent.IO_ERROR, connection_ioErrorHandler);
				connection.removeEventListener(SecurityErrorEvent.SECURITY_ERROR, connection_netSecurityErrorHandler);
				
				if (connection.connected)
					connection.close();
				
				connection = null;
			}
		}
		
		protected function connection_netStatusHandler(event:NetStatusEvent):void
		{
			var fse:FMSServerEvent;
			switch(event.info.code)
			{
				case "NetConnection.Connect.Success":
					fse = new FMSServerEvent(FMSServerEvent.CONNECT);
					fse.descript = "连接成功";
					break;
				case "NetConnection.Connect.Rejected":
					fse = new FMSServerEvent(FMSServerEvent.ERROR);
					fse.descript = "拒绝连接";
					break;
				case "NetConnection.Connect.InvalidApp":
					fse = new FMSServerEvent(FMSServerEvent.ERROR);
					fse.descript = "指定的应用程序没有找到";
					break;
				case "NetConnection.Connect.Failed":
					fse = new FMSServerEvent(FMSServerEvent.ERROR);
					fse.descript = "连接失败";
					break;
				case "NetConnection.Connect.AppShutDown":
					fse = new FMSServerEvent(FMSServerEvent.ERROR);
					fse.descript = "服务器应用程序已经关闭（由于资源耗用过大等原因）或者服务器已经关闭";
					break;
				case "NetConnection.Connect.Closed":
					fse = new FMSServerEvent(FMSServerEvent.DISCONNECT);
					fse.descript = "连接断开";
					break;
				case "NetStream.Play.Stop":
					fse = new FMSServerEvent(FMSServerEvent.DATA);
					fse.descript = "视频流播放停止";
					break;
				default : 
				{
					fse = new FMSServerEvent(FMSServerEvent.DATA)
					fse.descript = event.info.code;
					break;
				}
			}
			
			dispatchEvent(fse);
		}
		
		protected function connection_netSecurityErrorHandler(event:SecurityErrorEvent):void
		{
			var mse:FMSServerEvent = new FMSServerEvent(FMSServerEvent.ERROR);
			mse.descript = event.text;
			dispatchEvent(mse);
		}
		
		protected function connection_ioErrorHandler(event:IOErrorEvent):void
		{
			var mse:FMSServerEvent = new FMSServerEvent(FMSServerEvent.ERROR);
			mse.descript = event.text;
			dispatchEvent(mse);
		}
		
		protected function connection_asyncErrorHandler(event:AsyncErrorEvent):void
		{
			var mse:FMSServerEvent = new FMSServerEvent(FMSServerEvent.ERROR);
			mse.descript = event.text;
			dispatchEvent(mse);
		}
		
	}
}

class FMSClient 
{
	public function FMSClient(name:String)
	{
		clientName = name;
	}
	
	private var clientName:String;
	
	public function onMetaData(info:Object):void 
	{
		//		trace(clientName + " metadata: duration=" + info.duration + " width=" + info.width + " height=" + info.height + " framerate=" + info.framerate);
	}
	public function onCuePoint(info:Object):void 
	{
		//		trace(clientName + "cuepoint: time=" + info.time + " name=" + info.name + " type=" + info.type);
	}
	public function onBWDone():void
	{
	}
}