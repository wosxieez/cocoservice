package coco.net
{
	import flash.events.EventDispatcher;
	import flash.events.IEventDispatcher;
	import flash.utils.ByteArray;
	
	[ExcludeClass]
	public class SocketDataProcessor extends EventDispatcher
	{
		public function SocketDataProcessor(target:IEventDispatcher=null)
		{
			super(target);
		}
		
		
		//----------------------------------------------------------------------------------------------------------------
		//
		//  Socket消息包处理部分
		//
		//----------------------------------------------------------------------------------------------------------------
		
		protected var bufferBytes:ByteArray = new ByteArray();   // 缓冲区字节
		private var packetBytesLength:int = 0;  			   // 包字节长度
		private var packetBytes:ByteArray; 		               // 包字节
		private var processing:Boolean = false;				   // 包处理中
		
		protected function processSocketPacket():void
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
		
		protected function receiveMessage(message:String):void
		{
			// override here
		}
		
	}
}