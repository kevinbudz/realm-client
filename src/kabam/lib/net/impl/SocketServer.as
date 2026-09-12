package kabam.lib.net.impl
{
   import com.hurlant.crypto.symmetric.ICipher;
   import flash.events.Event;
   import flash.events.IOErrorEvent;
   import flash.events.ProgressEvent;
   import flash.events.SecurityErrorEvent;
   import flash.net.Socket;
import flash.system.Security;
import flash.utils.ByteArray;
   import kabam.lib.net.api.MessageProvider;
   import org.osflash.signals.Signal;
   
   public class SocketServer
   {
      [Inject]
      public var messages:MessageProvider;
      
      [Inject]
      public var socket:Socket;
      
      public const connected:Signal = new Signal();
      public const closed:Signal = new Signal();
      public const error:Signal = new Signal(String);
      private const unsentPlaceholder:Message = new Message(0);
      private const data:ByteArray = new ByteArray();
      private static const MIN_MESSAGE_LENGTH:int = 5;
      private static const MAX_MESSAGE_LENGTH:int = 1048576;
      
      private var head:Message;
      private var tail:Message;
      private var messageLen:int = -1;
      
      public function SocketServer()
      {
         this.head = this.unsentPlaceholder;
         this.tail = this.unsentPlaceholder;
         super();
      }
      
      public function connect(server:String, port:int) : void
      {
         this.addListeners();
         this.messageLen = -1;
         this.socket.connect(server,port);
      }
      
      private function addListeners() : void
      {
         this.socket.addEventListener(Event.CONNECT,this.onConnect);
         this.socket.addEventListener(Event.CLOSE,this.onClose);
         this.socket.addEventListener(ProgressEvent.SOCKET_DATA,this.onSocketData);
         this.socket.addEventListener(IOErrorEvent.IO_ERROR,this.onIOError);
         this.socket.addEventListener(SecurityErrorEvent.SECURITY_ERROR,this.onSecurityError);
      }
      
      public function disconnect() : void
      {
         try {
            this.socket.close();
         }
         catch (error:Error) { }
         this.removeListeners();
         this.closed.dispatch();
      }
      
      private function removeListeners() : void
      {
         this.socket.removeEventListener(Event.CONNECT,this.onConnect);
         this.socket.removeEventListener(Event.CLOSE,this.onClose);
         this.socket.removeEventListener(ProgressEvent.SOCKET_DATA,this.onSocketData);
         this.socket.removeEventListener(IOErrorEvent.IO_ERROR,this.onIOError);
         this.socket.removeEventListener(SecurityErrorEvent.SECURITY_ERROR,this.onSecurityError);
      }

      public function sendMessage(msg:Message) : void
      {
         this.tail.next = msg;
         this.tail = msg;
         this.socket.connected && this.sendPendingMessages();
      }

      private function sendPendingMessages() : void
      {
         var temp:Message = this.head.next;
         var msg:Message = temp;

         if (!this.socket.connected) {
            return;
         }

         var i:int = 0;
         while (msg) {
            this.data.position = 0;
            this.data.length = 0;
            msg.writeToOutput(this.data);
            this.data.position = 0;
            this.socket.writeInt(this.data.bytesAvailable + 5);
            this.socket.writeByte(msg.id);
            this.socket.writeBytes(this.data);
            temp = msg;
            msg = msg.next;
            temp.consume();
            i++;
         }
         if (i > 0) {
            this.socket.flush();
         }
         this.unsentPlaceholder.next = null;
         this.unsentPlaceholder.prev = null;
         this.head = (this.tail = this.unsentPlaceholder);
      }
      
      private function onConnect(event:Event) : void
      {
         this.sendPendingMessages();
         this.connected.dispatch();
      }
      
      private function onClose(event:Event) : void
      {
         this.closed.dispatch();
      }
      
      private function onIOError(event:IOErrorEvent) : void
      {
         var message:String = this.parseString("Socket-Server IO Error: {0}",[event.text]);
         this.error.dispatch(message);
         this.closed.dispatch();
      }
      
      private function onSecurityError(event:SecurityErrorEvent) : void
      {
         var message:String = this.parseString("Socket-Server Security Error: {0}",[event.text]);
         this.error.dispatch(message);
         this.closed.dispatch();
      }

      private function onSocketData(_:ProgressEvent = null):void {
         var messageId:uint;
         var message:Message;
         var errorMessage:String;
         var bodyLen:int;
         while (true) {
            if (this.socket == null || !this.socket.connected) break;
            if (this.messageLen == -1) {
               if (this.socket.bytesAvailable < 4) break;
               try {
                  this.messageLen = this.socket.readInt();
               }
               catch (e:Error) {
                  errorMessage = this.parseString("Socket-Server Data Error: {0}: {1}", [e.name, e.message]);
                  this.error.dispatch(errorMessage);
                  this.messageLen = -1;
                  return;
               }
               if (this.messageLen < MIN_MESSAGE_LENGTH || this.messageLen > MAX_MESSAGE_LENGTH) {
                  this.logErrorAndClose("Socket-Server Protocol Error: Invalid message length {0}", [this.messageLen]);
                  this.messageLen = -1;
                  return;
               }
            }
            if (this.socket.bytesAvailable < this.messageLen - 4) break;
            try {
               messageId = this.socket.readUnsignedByte();
               this.data.position = 0;
               this.data.length = 0;
               bodyLen = this.messageLen - 5;
               if (bodyLen > 0) {
                  this.socket.readBytes(this.data, 0, bodyLen);
               }
               this.data.position = 0;
               this.messageLen = -1;
               message = this.messages.require(messageId);
               if (message == null) {
                  this.logErrorAndClose("Socket-Server Protocol Error: Unknown message", []);
                  return;
               }
               message.parseFromInput(this.data);
               message.consume();
            }
            catch (error:Error) {
               this.messageLen = -1;
               this.logErrorAndClose("Socket-Server Protocol Error: {0}", [error.toString()]);
               return;
            }
         }
      }
      
      private function logErrorAndClose(message:String, arguments:Array = null) : void
      {
         this.error.dispatch(this.parseString(message,arguments));
         this.disconnect();
      }
      
      private function parseString(error:String, arguments:Array) : String
      {
         if (arguments == null)
         {
            return error;
         }
         var count:int = arguments.length;
         for(var i:int = 0; i < count; i++)
         {
            error = error.replace("{" + i + "}",arguments[i]);
         }
         return error;
      }
   }
}
