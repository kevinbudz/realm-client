package kabam.rotmg.stage3D.graphic3D
{
   /** Location of one sprite inside a SpriteAtlas page. w/h are the pow2-padded sprite size. */
   public class AtlasEntry
   {
      public var page:AtlasPage;
      public var generation:int;
      public var x:int;
      public var y:int;
      public var w:int;
      public var h:int;
      public var u0:Number;
      public var v0:Number;
      public var u1:Number;
      public var v1:Number;

      public function AtlasEntry()
      {
         super();
      }
   }
}
