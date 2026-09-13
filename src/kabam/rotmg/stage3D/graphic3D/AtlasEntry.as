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
      // Tilable slots (scrolling/repeat sprites): the page holds a 2x2 replication of the
      // sprite so any fractional scroll offset samples continuous content with the clamp
      // sampler. x/y/w/h still describe one sprite copy at the block origin; uSpan/vSpan
      // are that copy's UV size, and u1/v1 span the whole 2x2 block.
      public var tilable:Boolean = false;
      public var uSpan:Number = 0;
      public var vSpan:Number = 0;

      public function AtlasEntry()
      {
         super();
      }
   }
}
