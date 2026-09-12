package kabam.rotmg.stage3D.graphic3D
{
   import flash.display.BitmapData;
   import flash.display3D.textures.Texture;

   /**
    * One texture page with simple shelf packing (one shelf height per shelf; sizes are pow2).
    * Every slot owns a 1-texel border on all sides (filled with replicated edge texels so
    * sampling at the slot edge behaves like clamp-to-edge on an individual texture).
    */
   public class AtlasPage
   {
      public static const BORDER:int = 1;

      public var texture:Texture;
      // CPU fill mode only: page contents, re-uploaded when dirty.
      public var bitmap:BitmapData;
      public var dirty:Boolean = false;
      public var lastUsed:int = 0;
      public var generation:int = 0;
      public var needsClear:Boolean = true;
      private var shelfY:Vector.<int> = new Vector.<int>();
      private var shelfH:Vector.<int> = new Vector.<int>();
      private var shelfX:Vector.<int> = new Vector.<int>();
      private var nextShelfY:int = 0;

      public function AtlasPage(texture:Texture)
      {
         this.texture = texture;
      }

      public function alloc(w:int, h:int) : AtlasEntry
      {
         var n:int = this.shelfH.length;
         var i:int = 0;
         var pitchW:int = w + 2 * BORDER;
         var pitchH:int = h + 2 * BORDER;
         for(i = 0; i < n; i++)
         {
            if(this.shelfH[i] == h && this.shelfX[i] + pitchW <= SpriteAtlas.PAGE_SIZE)
            {
               return this.place(i,w,h);
            }
         }
         if(this.nextShelfY + pitchH <= SpriteAtlas.PAGE_SIZE)
         {
            this.shelfY.push(this.nextShelfY);
            this.shelfH.push(h);
            this.shelfX.push(0);
            this.nextShelfY += pitchH;
            return this.place(n,w,h);
         }
         return null;
      }

      private function place(shelf:int, w:int, h:int) : AtlasEntry
      {
         var e:AtlasEntry = new AtlasEntry();
         e.page = this;
         e.generation = this.generation;
         e.x = this.shelfX[shelf] + BORDER;
         e.y = this.shelfY[shelf] + BORDER;
         e.w = w;
         e.h = h;
         var inv:Number = 1 / SpriteAtlas.PAGE_SIZE;
         e.u0 = e.x * inv;
         e.v0 = e.y * inv;
         e.u1 = (e.x + w) * inv;
         e.v1 = (e.y + h) * inv;
         this.shelfX[shelf] += w + 2 * BORDER;
         return e;
      }

      public function reset() : void
      {
         this.generation++;
         this.shelfY.length = 0;
         this.shelfH.length = 0;
         this.shelfX.length = 0;
         this.nextShelfY = 0;
         this.needsClear = true;
      }
   }
}
