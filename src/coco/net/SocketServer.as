package coco.net {
	import coco.event.SocketEvent;
	
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.IEventDispatcher;
	import flash.events.ProgressEvent;
	import flash.events.ServerSocketConnectEvent;
	import flash.events.TimerEvent;
	import flash.net.ServerSocket;
	import flash.net.Socket;
	import flash.utils.Timer;
	
	[Event(name="connect", type="coco.event.SocketEvent")]
	
	[Event(name="disconnect", type="coco.event.SocketEvent")]
	
	[Event(name="log", type="coco.event.SocketEvent")]
	
	/**
	 * Socket服务端
	 */
	public class SocketServer extends EventDispatcher {
		public function SocketServer(target:IEventDispatcher = null) {
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
		private static var instance:SocketServer;
		
		public static function getInstance():SocketServer {
			inRightWay = true;
			
			if (!instance)
				instance = new SocketServer();
			
			return instance;
		}
		
		
		//----------------------------------------------------------------------------------------------------------------
		//
		//  Variables
		//
		//----------------------------------------------------------------------------------------------------------------
		
		
		//----------------------------------------------------------------------------------------------------------------
		//
		//  Methods
		//
		//----------------------------------------------------------------------------------------------------------------
		
		private var initialized:Boolean = false;
		private var c1Socket:ServerSocket;
		private var c1PolicySocket:ServerSocket;
		private var checkTimer:Timer;
		private var currentPolicyPort:int;
		private var currentPort:int;
		
		/**
		 * 服务器启动
		 */
		public function start(port:int = 12016, policyPort:int = 12015):void {
			if (initialized) return;
			initialized = true;
			
			currentPort = port;
			currentPolicyPort = policyPort;
			
			initC1PolicySocket();
			initC1Socket();
			
			// 60s检查一次服务情况
			checkTimer = new Timer(60000);
			checkTimer.addEventListener(TimerEvent.TIMER, checkTimer_timerHandler);
			checkTimer.start();
		}
		
		/**
		 * 服务器停止
		 */
		public function stop():void {
			if (!initialized) return;
			initialized = false;
			
			if (checkTimer) {
				checkTimer.removeEventListener(TimerEvent.TIMER, checkTimer_timerHandler);
				checkTimer.stop();
				checkTimer = null;
			}
			
			disposeC1Socket();
			disposeC1PolicySocket();
		}
		
		protected function checkTimer_timerHandler(event:TimerEvent):void {
			if (!c1PolicySocket || !c1PolicySocket.listening) {
				log("策略服务异常,开始重启");
				initC1PolicySocket();
			}
			
			if (!c1Socket || !c1Socket.listening) {
				log("服务异常,开始重启");
				initC1Socket();
			}
		}
		
		private function initC1PolicySocket():void {
			try {
				// 开启策略服务
				c1PolicySocket = new ServerSocket();
				c1PolicySocket.addEventListener(ServerSocketConnectEvent.CONNECT, c1PolicySocket_connectHandler);
				c1PolicySocket.bind(currentPolicyPort);
				c1PolicySocket.listen();
				log("启动策略服务成功", currentPolicyPort);
			}
			catch (error:Error) {
				log("启动策略服务失败," + error.message);
			}
		}
		
		private function disposeC1PolicySocket():void {
			if (c1PolicySocket) {
				try {
					c1PolicySocket.removeEventListener(ServerSocketConnectEvent.CONNECT, c1PolicySocket_connectHandler);
					c1PolicySocket.close();
					c1PolicySocket = null;
					log("关闭策略服务成功");
				}
				catch (error:Error) {
					log("关闭策略服务失败," + error.message);
				}
			}
		}
		
		private function initC1Socket():void {
			try {
				c1Socket = new ServerSocket();
				c1Socket.addEventListener(ServerSocketConnectEvent.CONNECT, c1Socket_connectHandler);
				c1Socket.addEventListener(Event.CLOSE, c1Socket_closeHandler);
				c1Socket.bind(currentPort);
				c1Socket.listen();
				log("启动服务成功", currentPort);
			}
			catch (error:Error) {
				log("启动服务失败," + error.message);
			}
		}
		
		private function disposeC1Socket():void {
			if (c1Socket) {
				try {
					c1Socket.removeEventListener(ServerSocketConnectEvent.CONNECT, c1Socket_connectHandler);
					c1Socket.removeEventListener(Event.CLOSE, c1Socket_closeHandler);
					c1Socket.close();
					c1Socket = null;
					log("关闭服务成功");
				}
				catch (error:Error) {
					log("关闭服务失败," + error.message);
				}
			}
		}
		
		private function initC2Socket(c2Socket:Socket):void {
			var connectEvent:SocketEvent = new SocketEvent(SocketEvent.CONNECT);
			connectEvent.client = new SocketServerClient(c2Socket);
			connectEvent.client.addEventListener(SocketEvent.DISCONNECT, client_disconnectHandler);
			connectEvent.client.addEventListener(SocketEvent.LOG, client_logHandler);
			log("客户端已连接: " + connectEvent.client.remoteAddress + ":" + connectEvent.client.remotePort);
			dispatchEvent(connectEvent);
		}
		
		protected function c1Socket_connectHandler(event:ServerSocketConnectEvent):void {
			initC2Socket(event.socket);
		}
		
		private function client_disconnectHandler(event:SocketEvent):void {
			event.client.removeEventListener(SocketEvent.DISCONNECT, client_disconnectHandler);
			var connectEvent:SocketEvent = new SocketEvent(SocketEvent.DISCONNECT);
			connectEvent.client = event.client
			log("客户端已断开: " + connectEvent.client.remoteAddress + ":" + connectEvent.client.remotePort);
			dispatchEvent(connectEvent);
		}
		
		private function client_logHandler(event:SocketEvent):void {
			log(event.descript)
		}
		
		protected function c1Socket_closeHandler(event:Event):void {
			disposeC1Socket();
		}
		
		//----------------------------------------------------------------------------------------------------------------
		//
		//  日志输出
		//
		//----------------------------------------------------------------------------------------------------------------
		
		private function log(...args):void {
			var arg:Array = args as Array;
			if (arg.length > 0) {
				arg[0] = "[Socket通信服务] " + arg[0];
				var ce:SocketEvent = new SocketEvent(SocketEvent.LOG);
				ce.descript = args.join(" ");
				dispatchEvent(ce);
			}
		}
		
		//----------------------------------------------------------------------------------------------------------------
		//
		//  请求策略文件
		//
		//----------------------------------------------------------------------------------------------------------------
		
		private var policyFile:String =
				'<cross-domain-policy>' +
				'<site-control permitted-cross-domain-policies="all"/>' +
				'<allow-access-from domain="*" to-ports="' + currentPort + '"/>' +
				'</cross-domain-policy> ';
		
		private var policySocket:Socket;
		
		protected function c1PolicySocket_connectHandler(event:ServerSocketConnectEvent):void {
			log("收到策略请求");
			policySocket = event.socket;
			policySocket.addEventListener(ProgressEvent.SOCKET_DATA, policySocket_dataHandler);
		}
		
		protected function policySocket_dataHandler(event:ProgressEvent):void {
			var data:String;
			while (policySocket.bytesAvailable) {
				data = policySocket.readUTFBytes(policySocket.bytesAvailable);
			}
			
			if (data == "<policy-file-request/>") {
				log("回发策略数据")
				policySocket.writeUTFBytes(policyFile);
				policySocket.flush();
				policySocket.close();
			}
		}
		
	}
}