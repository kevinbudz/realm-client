package com.company.assembleegameclient.map
{
   import com.company.assembleegameclient.background.Background;
   import com.company.assembleegameclient.engine3d.Face3D;
   import com.company.assembleegameclient.game.GameSprite;
import com.company.assembleegameclient.game.events.ReconnectEvent;
import com.company.assembleegameclient.map.mapoverlay.MapOverlay;
   import com.company.assembleegameclient.map.partyoverlay.PartyOverlay;
   import com.company.assembleegameclient.objects.BasicObject;
   import com.company.assembleegameclient.objects.GameObject;
   import com.company.assembleegameclient.objects.Party;
   import com.company.assembleegameclient.objects.Player;
   import com.company.assembleegameclient.parameters.Parameters;
   import com.company.assembleegameclient.util.ConditionEffect;
   import com.company.assembleegameclient.util.FrameProfiler;
   import flash.display.Graphics;
import flash.display.GraphicsBitmapFill;
import flash.display.StageScaleMode;
import flash.display.GraphicsSolidFill;
import flash.display.IGraphicsData;
import flash.display.Sprite;
import flash.display3D.Context3D;
import flash.filters.BlurFilter;
import flash.filters.ColorMatrixFilter;
import flash.geom.ColorTransform;
import flash.geom.Point;
import flash.geom.Rectangle;
import flash.utils.Dictionary;
import kabam.rotmg.core.StaticInjectorContext;
import kabam.rotmg.stage3D.GraphicsFillExtra;
import kabam.rotmg.stage3D.Object3D.Object3DStage3D;
import kabam.rotmg.stage3D.Render3D;
import kabam.rotmg.stage3D.Renderer;
import kabam.rotmg.stage3D.graphic3D.Graphic3D;
import kabam.rotmg.stage3D.graphic3D.TextureFactory;
import org.osflash.signals.Signal;

public class Map extends Sprite
   {
      protected static const BLIND_FILTER:ColorMatrixFilter = new ColorMatrixFilter([0.05,0.05,0.05,0,0,0.05,0.05,0.05,0,0,0.05,0.05,0.05,0,0,0.05,0.05,0.05,1,0]);
      protected static var BREATH_CT:ColorTransform = new ColorTransform(255 / 255,55 / 255,0 / 255,0);

      public var gs_:GameSprite;
      public var width_:int;
      public var height_:int;
      public var name_:String;
      public var back_:int;
      public var showDisplays_:Boolean;
      public var allowPlayerTeleport_:Boolean;
      public var background_:Background = null;
      public var map_:Sprite;
      public var hurtOverlay_:HurtOverlay = null;
      public var gradientOverlay_:GradientOverlay = null;
      public var mapOverlay_:MapOverlay = null;
      public var partyOverlay_:PartyOverlay = null;
      public var squareList_:Vector.<Square>;
      public var squares_:Vector.<Square>;
      public var goDict_:Dictionary;
      public var boDict_:Dictionary;
      // Flat lists mirroring goDict_/boDict_ for fast per-frame iteration (Dictionary for-each is slow
      // in AVM2). Storage order is insertion order; draw order comes from natively sorting the small
      // per-frame visible lists, identical to the old Array.sortOn.
      public var goList_:Vector.<GameObject>;
      public var boList_:Vector.<BasicObject>;
      public var merchLookup_:Object;
      public var player_:Player = null;
      public var party_:Party = null;
      public var quest_:Quest = null;
      private var inUpdate_:Boolean = false;
      private var objsToAdd_:Vector.<BasicObject>;
      private var idsToRemove_:Vector.<int>;
      private var graphicsData_:Vector.<IGraphicsData>;
      private var graphicsData3d_:Vector.<Object3DStage3D>;
      private var lastSoftwareClear:Boolean = false;
      // Still-camera detection for Face3D.skipMatrixCompute: tile screen projection
      // is a pure function of (wToS_, clipRect_), so an identical camera reuses all
      // tile matrices. Compared once per frame; the snapshot updates every frame.
      private var lastWToS_:Vector.<Number> = new Vector.<Number>(16,true);
      private var lastClipX:Number = NaN;
      private var lastClipY:Number = NaN;
      private var lastClipW:Number = NaN;
      private var lastClipH:Number = NaN;
      private var camSnapInit_:Boolean = false;
      private var wToSScratch_:Vector.<Number> = new Vector.<Number>(16,true);
      public var visible_:Vector.<BasicObject>;
      public var visibleUnder_:Vector.<BasicObject>;
      private var visibleGo_:Vector.<BasicObject>;
      private var visibleBo_:Vector.<BasicObject>;
      private var screenCenterW_:Point;
      public var visibleSquares_:Vector.<Square>;
      public var topSquares_:Vector.<Square>;
      // Bumped on every tile mutation (setGroundTile). Lets Graphic3D cache all
      // fully static tile quads across frames (see draw).
      public var tileVersion_:int = 0;
      // Visible squares with scrolling faces, recorded on tile-cache rebuild frames
      // and redrawn every frame (scroll offsets advance; their matrices stay cached).
      public var tileAnimSquares_:Vector.<Square>;
      public var signalRenderSwitch:Signal;
      public var wasLastFrameGpu:Boolean = false;
      public var movesRequested_:int;
      public var gotoRequested_:int;
      public var nextProjectileId_:int;
      public var hittable_:Vector.<GameObject>;
      public var pushX_:Number;
      public var pushY_:Number;
      public var reconnect_:ReconnectEvent;
      
      public function Map(gs:GameSprite)
      {
         this.map_ = new Sprite();
         this.squareList_ = new Vector.<Square>();
         this.squares_ = new Vector.<Square>();
         this.goDict_ = new Dictionary();
         this.boDict_ = new Dictionary();
         this.goList_ = new Vector.<GameObject>();
         this.boList_ = new Vector.<BasicObject>();
         this.merchLookup_ = new Object();
         this.objsToAdd_ = new Vector.<BasicObject>();
         this.idsToRemove_ = new Vector.<int>();
         this.graphicsData_ = new Vector.<IGraphicsData>();
         this.graphicsData3d_ = new Vector.<Object3DStage3D>();
         this.visible_ = new Vector.<BasicObject>();
         this.visibleUnder_ = new Vector.<BasicObject>();
         this.visibleGo_ = new Vector.<BasicObject>();
         this.visibleBo_ = new Vector.<BasicObject>();
         this.screenCenterW_ = new Point();
         this.visibleSquares_ = new Vector.<Square>();
         this.topSquares_ = new Vector.<Square>();
         this.tileAnimSquares_ = new Vector.<Square>();
         super();
         this.gs_ = gs;
         this.hurtOverlay_ = new HurtOverlay();
         this.gradientOverlay_ = new GradientOverlay();
         this.mapOverlay_ = new MapOverlay();
         this.partyOverlay_ = new PartyOverlay(this);
         this.party_ = new Party(this);
         this.quest_ = new Quest(this);
         this.signalRenderSwitch = new Signal();
         this.hittable_ = new Vector.<GameObject>();
         wasLastFrameGpu = Parameters.isGpuRender();
         Parameters.GPURenderFrame = wasLastFrameGpu
      }
      
      public function setProps(width:int, height:int, name:String, back:int, allowPlayerTeleport:Boolean, showDisplays:Boolean) : void
      {
         this.width_ = width;
         this.height_ = height;
         this.name_ = name;
         this.back_ = back;
         this.allowPlayerTeleport_ = allowPlayerTeleport;
         this.showDisplays_ = showDisplays;
      }
      
      public function initialize() : void
      {
         this.squares_.length = this.width_ * this.height_;
         this.background_ = Background.getBackground(this.back_);
         if(this.background_ != null)
         {
            addChild(this.background_);
         }
         addChild(this.map_);
         addChild(this.hurtOverlay_);
         addChild(this.gradientOverlay_);
         addChild(this.mapOverlay_);
         addChild(this.partyOverlay_);
      }
      
      public function dispose() : void
      {
         var square:Square = null;
         var go:GameObject = null;
         var bo:BasicObject = null;
         this.gs_ = null;
         this.background_ = null;
         this.map_ = null;
         this.hurtOverlay_ = null;
         this.gradientOverlay_ = null;
         this.mapOverlay_ = null;
         this.partyOverlay_ = null;
         for each(square in this.squareList_)
         {
            square.dispose();
         }
         this.squareList_.length = 0;
         this.squareList_ = null;
         this.squares_.length = 0;
         this.squares_ = null;
         for each(go in this.goList_)
         {
            go.dispose();
         }
         this.goDict_ = null;
         this.goList_ = null;
         for each(bo in this.boList_)
         {
            bo.dispose();
         }
         this.boDict_ = null;
         this.boList_ = null;
         this.visible_ = null;
         this.visibleUnder_ = null;
         this.visibleGo_ = null;
         this.visibleBo_ = null;
         this.merchLookup_ = null;
         this.player_ = null;
         this.party_ = null;
         this.quest_ = null;
         this.objsToAdd_ = null;
         this.idsToRemove_ = null;
         this.hittable_.length = 0;
         this.hittable_ = null;
         // GPU caches (atlas pages, programs) are context-global and shared across maps; disposing
         // them here replayed a full-page atlas upload storm on every map change. Compact only the
         // individual-texture LRU. Per-instance fill state is strong-keyed and must still go.
         TextureFactory.onMapChange();
         StaticInjectorContext.getInjector().getInstance(Graphic3D).invalidateTileCache();
         GraphicsFillExtra.dispose();
      }

      public function update(time:int, dt:int) : void
      {
         var bo:BasicObject = null;
         var go:GameObject = null;
         var objId:int = 0;
         var i:int = 0;
         var n:int = 0;
         this.inUpdate_ = true;

         this.hittable_.length = 0;
         var goList:Vector.<GameObject> = this.goList_;
         n = goList.length;
         for(i = 0; i < n; i++)
         {
            go = goList[i];
            if(!go.update(time,dt))
            {
               this.idsToRemove_.push(go.objectId_);
            }
            else
            {
               if (go.props_.isEnemy_)
               {
                  if (go.isTargetable())
                  {
                     this.hittable_.push(go);
                  }
               }
            }
         }

         var boList:Vector.<BasicObject> = this.boList_;
         n = boList.length;
         for(i = 0; i < n; i++)
         {
            bo = boList[i];
            if(!bo.update(time,dt))
            {
               this.idsToRemove_.push(bo.objectId_);
            }
         }

         this.inUpdate_ = false;
         for each(bo in this.objsToAdd_)
         {
            this.internalAddObj(bo);
         }

         this.objsToAdd_.length = 0;
         for each(objId in this.idsToRemove_)
         {
            this.internalRemoveObj(objId);
         }

         this.idsToRemove_.length = 0;
         this.party_.update(time,dt);

         if (this.player_)
         {
            if (this.movesRequested_ > 0)
            {
               gs_.gsc_.move(this.player_, time);
               this.player_.onMove();
               this.movesRequested_--;
            }

            if (this.gotoRequested_ > 0)
            {
               gs_.gsc_.gotoAck(time);
               this.gotoRequested_--;
            }
         }
      }
      
      public function pSTopW(xS:Number, yS:Number) : Point
      {
         var square:Square = null;
         var p:Point = null;
         for each(square in this.visibleSquares_)
         {
            if(square.faces_.length != 0 && square.faces_[0].face_.contains(xS,yS))
            {
               return new Point(square.center_.x,square.center_.y);
            }
         }
         return null;
      }
      
      public function setGroundTile(x:int, y:int, tileType:uint) : void
      {
         var yi:int = 0;
         var ind:int = 0;
         var n:Square = null;
         var square:Square = this.getSquare(x,y);
         square.setTileType(tileType);
         this.tileVersion_++;
         var xend:int = x < this.width_ - 1? x + 1 : x;
         var yend:int = y < this.height_ - 1? y + 1 : y;
         for(var xi:int = x > 0 ? x - 1: x; xi <= xend; xi++)
         {
            for(yi = y > 0? y - 1 : y; yi <= yend; yi++)
            {
               ind = xi + yi * this.width_;
               n = this.squares_[ind];
               if(n != null && (n.props_.hasEdge_ || n.tileType_ != tileType))
               {
                  n.faces_.length = 0;
               }
            }
         }
      }
      
      public function addObj(bo:BasicObject, posX:Number, posY:Number) : void
      {
         bo.x_ = posX;
         bo.y_ = posY;
         if(this.inUpdate_)
         {
            this.objsToAdd_.push(bo);
         }
         else
         {
            this.internalAddObj(bo);
         }
      }
      
      public function internalAddObj(bo:BasicObject) : void
      {
         if(!bo.addTo(this,bo.x_,bo.y_))
         {
            trace("ERROR: adding: " + bo);
            return;
         }
         var go:GameObject = bo as GameObject;
         var dict:Dictionary = go != null?this.goDict_:this.boDict_;
         if(dict[bo.objectId_] != null)
         {
            trace("ERROR: duplicate add: " + bo + " would replace: " + dict[bo.objectId_]);
            return;
         }
         dict[bo.objectId_] = bo;
         if(go != null)
         {
            this.goList_.push(go);
         }
         else
         {
            this.boList_.push(bo);
         }
      }
      
      public function removeObj(objectId:int) : void
      {
         if(this.inUpdate_)
         {
            this.idsToRemove_.push(objectId);
         }
         else
         {
            this.internalRemoveObj(objectId);
         }
      }
      
      public function internalRemoveObj(objectId:int) : void
      {
         var idx:int = 0;
         var dict:Dictionary = this.goDict_;
         var bo:BasicObject = dict[objectId];
         if(bo != null)
         {
            idx = this.goList_.indexOf(GameObject(bo));
            if(idx >= 0)
            {
               this.goList_.splice(idx,1);
            }
         }
         else
         {
            dict = this.boDict_;
            bo = dict[objectId];
            if(bo == null)
            {
               return;
            }
            idx = this.boList_.indexOf(bo);
            if(idx >= 0)
            {
               this.boList_.splice(idx,1);
            }
         }
         bo.removeFromMap();
         delete dict[objectId];
      }

      // Draw-order comparator for (sortVal_, objectId_) ascending, identical to the old
      // Array.sortOn(VISIBLE_SORT_FIELDS). Used with the native Vector.sort on the small
      // per-frame visible lists only; the goList_/boList_ storage vectors are never sorted.
      private static function compareDrawOrder(a:BasicObject, b:BasicObject) : int
      {
         if(a.sortVal_ != b.sortVal_)
         {
            return a.sortVal_ < b.sortVal_ ? -1 : 1;
         }
         if(a.objectId_ != b.objectId_)
         {
            return a.objectId_ < b.objectId_ ? -1 : 1;
         }
         return 0;
      }

      // Merge two sorted vectors into `out` preserving (sortVal_, objectId_) order.
      private static function mergeSorted(a:Vector.<BasicObject>, b:Vector.<BasicObject>, out:Vector.<BasicObject>) : void
      {
         var an:int = a.length;
         var bn:int = b.length;
         var ai:int = 0;
         var bi:int = 0;
         var x:BasicObject = null;
         var y:BasicObject = null;
         out.length = 0;
         while(ai < an && bi < bn)
         {
            x = a[ai];
            y = b[bi];
            if(y.sortVal_ < x.sortVal_ || y.sortVal_ == x.sortVal_ && y.objectId_ < x.objectId_)
            {
               out.push(y);
               bi++;
            }
            else
            {
               out.push(x);
               ai++;
            }
         }
         while(ai < an)
         {
            out.push(a[ai++]);
         }
         while(bi < bn)
         {
            out.push(b[bi++]);
         }
      }
      
      public function getSquare(posX:Number, posY:Number) : Square
      {
         if(posX < 0 || posX >= this.width_ || posY < 0 || posY >= this.height_)
         {
            return null;
         }
         var ind:int = int(posX) + int(posY) * this.width_;
         var square:Square = this.squares_[ind];
         if(square == null)
         {
            square = new Square(this,int(posX),int(posY));
            this.squares_[ind] = square;
            this.squareList_.push(square);
         }
         return square;
      }
      
      public function lookupSquare(x:int, y:int) : Square
      {
         if(x < 0 || x >= this.width_ || y < 0 || y >= this.height_)
         {
            return null;
         }
         return this.squares_[x + y * this.width_];
      }
      
      // True when the camera projection is bit-identical to last frame, meaning all
      // static tile matrices can be reused (Face3D.skipMatrixCompute). Compares the
      // world-to-screen matrix plus clip rect once per frame; the snapshot refreshes
      // every call, so mid-draw repeats return the same answer. Camera is a Camera
      // (wToS_:Matrix3D, clipRect_:Rectangle).
      private function cameraStill(camera:Camera) : Boolean
      {
         var i:int = 0;
         var still:Boolean = this.camSnapInit_;
         var clip:Rectangle = camera.clipRect_;
         if(still)
         {
            still = this.lastClipX == clip.x && this.lastClipY == clip.y
               && this.lastClipW == clip.width && this.lastClipH == clip.height;
         }
         if(still)
         {
            camera.wToS_.copyRawDataTo(this.wToSScratch_);
            for(i = 0; i < 16; i++)
            {
               if(this.wToSScratch_[i] != this.lastWToS_[i])
               {
                  still = false;
                  break;
               }
            }
         }
         else
         {
            camera.wToS_.copyRawDataTo(this.wToSScratch_);
         }
         for(i = 0; i < 16; i++)
         {
            this.lastWToS_[i] = this.wToSScratch_[i];
         }
         this.lastClipX = clip.x;
         this.lastClipY = clip.y;
         this.lastClipW = clip.width;
         this.lastClipH = clip.height;
         this.camSnapInit_ = true;
         return still;
      }

      // One tile emission pass over the visible rect. Books every visible square
      // (lastVisible_, visibleSquares_, topSquares_) but draws only squares whose
      // animated status matches animatedPass, so pass 1 (false) emits the purely
      // static prefix consumed by the tile cache and pass 2 (true) the scrollers
      // (also recorded into tileAnimSquares_ for cache-hit frames).
      private function drawTilePass(squares:Vector.<Square>, graphicsData:Vector.<IGraphicsData>,
         camera:Camera, time:int, centerX:Number, centerY:Number, maxDistSq:Number,
         xStart:int, xEnd:int, yStart:int, yEnd:int, animatedPass:Boolean) : void
      {
         var square:Square = null;
         var dX:Number = NaN;
         var dY:Number = NaN;
         var distSq:Number = NaN;
         for(var xi:int = xStart; xi <= xEnd; xi++)
         {
            for(var yi:int = yStart; yi <= yEnd; yi++)
            {
               square = squares[xi + yi * this.width_];
               if(square == null)
               {
                  continue;
               }
               dX = centerX - square.center_.x;
               dY = centerY - square.center_.y;
               distSq = dX * dX + dY * dY;
               if(distSq > maxDistSq)
               {
                  continue;
               }
               square.lastVisible_ = time;
               if(square.isAnimated() == animatedPass)
               {
                  square.draw(graphicsData,camera,time);
                  if(animatedPass)
                  {
                     this.tileAnimSquares_.push(square);
                  }
               }
               this.visibleSquares_.push(square);
               if(square.topFace_ != null)
               {
                  this.topSquares_.push(square);
               }
            }
         }
      }

      public function draw(camera:Camera, time:int) : void
      {
         var isGpuRender:Boolean = Parameters.isGpuRender(); // cache result for faster access
         Parameters.GPURenderFrame = isGpuRender;
         if (wasLastFrameGpu != isGpuRender) {
            var context:Context3D = WebMain.STAGE.stage3Ds[0].context3D;
            if (wasLastFrameGpu && context != null &&
                    context.driverInfo.toLowerCase().indexOf("disposed") == -1) {
               context.clear();
               context.present();
            }
            else {
               map_.graphics.clear();
            }
            signalRenderSwitch.dispatch(wasLastFrameGpu);
            wasLastFrameGpu = isGpuRender;
         }

         var filter:uint = 0;
         var render3D:Render3D = null;
         var i:int = 0;
         var square:Square = null;
         var go:GameObject = null;
         var bo:BasicObject = null;
         var b:Number = NaN;
         var t:Number = NaN;
         var d:Number = NaN;
         var screenRect:Rectangle = camera.clipRect_;
         if(stage.scaleMode == StageScaleMode.NO_SCALE)
         {
            x = -screenRect.x * Parameters.data_.mscale;
            y = -screenRect.y * Parameters.data_.mscale;
         }
         else
         {
            x = -screenRect.x;
            y = -screenRect.y;
         }
         var distW:Number = (-screenRect.y - screenRect.height / 2) / 50;
         var screenCenterW:Point = this.screenCenterW_;
         screenCenterW.x = camera.x_ + distW * Math.cos(camera.angleRad_ - Math.PI / 2);
         screenCenterW.y = camera.y_ + distW * Math.sin(camera.angleRad_ - Math.PI / 2);
         if(this.background_ != null)
         {
            this.background_.draw(camera,time);
         }

         this.visible_.length = 0;
         this.visibleUnder_.length = 0;
         // NB: visibleSquares_/topSquares_ persist across tile-cache hits (cleared in
         // the miss branch below). Clearing them here starved the hit path: nothing
         // repopulated them, so lastVisible_ restamping touched zero squares and the
         // collect phase culled every entity, model and top tile.

         var delta:int = camera.maxDist_;
         var xStart:int = Math.max(0,screenCenterW.x - delta);
         var xEnd:int = Math.min(this.width_ - 1,screenCenterW.x + delta);
         var yStart:int = Math.max(0,screenCenterW.y - delta);
         var yEnd:int = Math.min(this.height_ - 1,screenCenterW.y + delta);

         this.graphicsData_.length = 0;
         this.graphicsData3d_.length = 0;

         // Visible tiles. With a still camera every tile matrix is identical to last
         // frame (see cameraStill below); Face3D then re-pushes its cached triple.
         // Pass 1 draws fully static squares (the Graphic3D tile-cache prefix) and
         // pass 2 the scrolling squares, which are redrawn every frame. Static and
         // scrolling tiles are coplanar and non-overlapping, so grouping them only
         // changes which tile wins sub-pixel seam ties.
         FrameProfiler.begin(FrameProfiler.TILES);
         var still:Boolean = this.cameraStill(camera);
         // skipMatrixCompute is assigned per-branch below, not here. Miss frames
         // must recompute (false): scroll-hit frames skip the static Face3D walk,
         // leaving static caches at snapshot-base positions, so a still-miss right
         // after moving (stop) must NOT reuse them as if they were last frame's.
         var squares:Vector.<Square> = this.squares_;
         var graphicsData:Vector.<IGraphicsData> = this.graphicsData_;
         var maxDistSq:Number = camera.maxDistSq_;
         var centerX:Number = screenCenterW.x;
         var centerY:Number = screenCenterW.y;
         var tileGraphic:Graphic3D = StaticInjectorContext.getInjector().getInstance(Graphic3D);
         var gpuTilePath:Boolean = isGpuRender && Renderer.inGame;
         // Batch verts bake the NDC transform, so the cache key includes every input
         // cameraStill cannot see: backbuffer size, zoom, centering and game state.
         var viewKey:String = screenRect.x + "|" + screenRect.y + "|" + screenRect.width + "|" + screenRect.height + "|"
            + WebMain.STAGE.stageWidth + "|" + WebMain.STAGE.stageHeight + "|" + WebMain.hudWidth() + "|"
            + Parameters.data_.mscale + "|" + Parameters.data_.stageScale + "|"
            + Parameters.data_.centerOnPlayer + "|" + Renderer.inGame;
         // wToSScratch_ holds the current camera raw (see cameraStill above); passed
         // by reference and copied inside checkTileCache, so no per-frame alloc.
         var tileCacheHit:Boolean = tileGraphic.checkTileCache(this,this.tileVersion_,still,gpuTilePath,viewKey,this.wToSScratch_);
         if(tileCacheHit)
         {
            // Still hit: identical camera, same static quads. Scroll hit: small pure
            // translation; the snapshot covers the same integer tile range plus the
            // snapshot overdraw margin, so shifting its verts (see primeTileCache)
            // reproduces the rebuild. Either way restamp visibility (entity culling
            // reads lastVisible_) and redraw only the scrollers; their matrices are
            // recomputed when moving (skipMatrixCompute false) and cached when still.
            // Scroll-hit frames leave static Face3D caches untouched (stale base).
            Face3D.skipMatrixCompute = still;
            Face3D.clipMargin_ = 10;
            var hitSquares:Vector.<Square> = this.visibleSquares_;
            var hitCount:int = hitSquares.length;
            for(var hi:int = 0; hi < hitCount; hi++)
            {
               hitSquares[hi].lastVisible_ = time;
            }
            var animSquares:Vector.<Square> = this.tileAnimSquares_;
            var animCount:int = animSquares.length;
            for(var ai:int = 0; ai < animCount; ai++)
            {
               animSquares[ai].draw(graphicsData,camera,time);
            }
            tileGraphic.tileStaticEnd_ = 0;
         }
         else
         {
            this.tileAnimSquares_.length = 0;
            this.visibleSquares_.length = 0;
            this.topSquares_.length = 0;
            // Static prefix overdraws for scroll coverage: widen the clip margin
            // (Face3D) and the tile range + radial cull by 2 tiles so scrolls up to
            // TILE_SCROLL_MAX_PX stay inside the snapshot. Animated tiles keep the
            // tight margin (redrawn every frame anyway).
            var staticDelta:Number = delta + 2;
            var sxStart:int = Math.max(0,centerX - staticDelta);
            var sxEnd:int = Math.min(this.width_ - 1,centerX + staticDelta);
            var syStart:int = Math.max(0,centerY - staticDelta);
            var syEnd:int = Math.min(this.height_ - 1,centerY + staticDelta);
            var staticMaxDist:Number = camera.maxDist_ + 2;
            var staticMaxDistSq:Number = staticMaxDist * staticMaxDist;
            // Miss: always recompute (see note above); the static caches may be
            // stale from skipped scroll-hit frames, never last frame's.
            Face3D.skipMatrixCompute = false;
            Face3D.clipMargin_ = Face3D.TILE_SNAPSHOT_MARGIN;
            this.drawTilePass(squares,graphicsData,camera,time,centerX,centerY,staticMaxDistSq,
               sxStart,sxEnd,syStart,syEnd,false);
            Face3D.clipMargin_ = 10;
            tileGraphic.tileStaticEnd_ = graphicsData.length;
            this.drawTilePass(squares,graphicsData,camera,time,centerX,centerY,maxDistSq,
               xStart,xEnd,yStart,yEnd,true);
         }
         Face3D.skipMatrixCompute = false;
         Face3D.clipMargin_ = 10;
         FrameProfiler.end(FrameProfiler.TILES);

         // visibility + screen-space depth for every object
         FrameProfiler.begin(FrameProfiler.COLLECT);
         var goList:Vector.<GameObject> = this.goList_;
         var boList:Vector.<BasicObject> = this.boList_;
         var n:int = goList.length;
         for(i = 0; i < n; i++)
         {
            go = goList[i];
            square = go.square_;
            if(square != null && square.lastVisible_ == time)
            {
               go.drawn_ = true;
               go.computeSortVal(camera);
            }
            else
            {
               go.drawn_ = false;
            }
         }
         n = boList.length;
         for(i = 0; i < n; i++)
         {
            bo = boList[i];
            square = bo.square_;
            if(square != null && square.lastVisible_ == time)
            {
               bo.drawn_ = true;
               bo.computeSortVal(camera);
            }
            else
            {
               bo.drawn_ = false;
            }
         }
         FrameProfiler.end(FrameProfiler.COLLECT);

         // Collect the visible objects in storage order, then natively sort just the
         // small visible lists. Sorting goList_/boList_ wholesale here used to dominate
         // the frame under projectile-heavy load (interpreter insertion sort is O(n^2)
         // once fast movers and constant spawn/despawn defeat the nearly-sorted case).
         FrameProfiler.begin(FrameProfiler.SORT);
         this.visibleGo_.length = 0;
         this.visibleBo_.length = 0;
         n = goList.length;
         for(i = 0; i < n; i++)
         {
            go = goList[i];
            if(!go.drawn_)
            {
               continue;
            }
            if(go.props_.drawUnder_)
            {
               if(go.props_.drawOnGround_)
               {
                  go.draw(graphicsData,camera,time);
               }
               else
               {
                  this.visibleUnder_.push(go);
               }
            }
            else
            {
               this.visibleGo_.push(go);
            }
         }
         n = boList.length;
         for(i = 0; i < n; i++)
         {
            bo = boList[i];
            if(bo.drawn_)
            {
               this.visibleBo_.push(bo);
            }
         }
         this.visibleGo_.sort(compareDrawOrder);
         this.visibleBo_.sort(compareDrawOrder);
         this.visibleUnder_.sort(compareDrawOrder);
         mergeSorted(this.visibleGo_,this.visibleBo_,this.visible_);
         FrameProfiler.end(FrameProfiler.SORT);

         // draw visible under (sorted above; storage order is no longer sorted)
         FrameProfiler.begin(FrameProfiler.DRAW_UNDER);
         var visibleUnder:Vector.<BasicObject> = this.visibleUnder_;
         n = visibleUnder.length;
         for(i = 0; i < n; i++)
         {
            visibleUnder[i].draw(graphicsData,camera,time);
         }
         FrameProfiler.end(FrameProfiler.DRAW_UNDER);

         // draw shadows
         var visible:Vector.<BasicObject> = this.visible_;
         n = visible.length;
         FrameProfiler.begin(FrameProfiler.SHADOWS);
         if(Parameters.data_.drawShadows)
         {
            for(i = 0; i < n; i++)
            {
               bo = visible[i];
               if(bo.hasShadow_)
               {
                  bo.drawShadow(graphicsData,camera,time);
               }
            }
         }
         FrameProfiler.end(FrameProfiler.SHADOWS);

         // draw visible
         FrameProfiler.begin(FrameProfiler.DRAW_OBJECTS);
         for(i = 0; i < n; i++)
         {
            bo = visible[i];
            bo.draw(graphicsData,camera,time);
            if (isGpuRender) {
               bo.draw3d(this.graphicsData3d_);
            }
         }
         FrameProfiler.end(FrameProfiler.DRAW_OBJECTS);

         // draw top squares (static geometry like tiles: same still-camera shortcut;
         // reuse the frame's still verdict: calling cameraStill again here would
         // always hit (it just snapshotted), freezing tops while moving).
         FrameProfiler.begin(FrameProfiler.TOP_TILES);
         Face3D.skipMatrixCompute = still;
         Face3D.clipMargin_ = 10;
         var topSquares:Vector.<Square> = this.topSquares_;
         n = topSquares.length;
         for(i = 0; i < n; i++)
         {
            topSquares[i].drawTop(graphicsData,camera,time);
         }
         Face3D.skipMatrixCompute = false;
         FrameProfiler.end(FrameProfiler.TOP_TILES);

         if(FrameProfiler.enabled)
         {
            FrameProfiler.frameObjects = visible.length + visibleUnder.length;
            FrameProfiler.frameTiles = this.visibleSquares_.length;
            FrameProfiler.frameGraphicsData = graphicsData.length;
         }

         // draw breath overlay
         if(this.player_ != null && this.player_.breath_ >= 0 && this.player_.breath_ < Parameters.BREATH_THRESH)
         {
            b = (Parameters.BREATH_THRESH - this.player_.breath_) / Parameters.BREATH_THRESH;
            t = Math.abs(Math.sin(time / 300)) * 0.75;
            BREATH_CT.alphaMultiplier = b * t;
            this.hurtOverlay_.transform.colorTransform = BREATH_CT;
            this.hurtOverlay_.visible = true;
            this.hurtOverlay_.x = screenRect.left;
            this.hurtOverlay_.y = screenRect.top;
         }
         else
         {
            this.hurtOverlay_.visible = false;
         }

         // draw side bar gradient
         if(this.player_ != null)
         {
            this.gradientOverlay_.visible = true;
            this.gradientOverlay_.x = screenRect.right - 10;
            this.gradientOverlay_.y = screenRect.top;
         }
         else
         {
            this.gradientOverlay_.visible = false;
         }

         // draw hw capable screen filters
         FrameProfiler.begin(FrameProfiler.PRESENT);
         if(isGpuRender && Renderer.inGame)
         {
            filter = this.getFilterIndex();
            render3D = StaticInjectorContext.getInjector().getInstance(Render3D);
            FrameProfiler.begin(FrameProfiler.GPU_DISPATCH);
            render3D.dispatch(this.graphicsData_,this.graphicsData3d_,width_,height_,camera,filter);
            FrameProfiler.end(FrameProfiler.GPU_DISPATCH);
            FrameProfiler.begin(FrameProfiler.GPU_SOFTWARE);
            // Software triples were already classified during the renderer's phase-1 walk
            // (Graphic3D.pushSoftware); blit them without re-scanning the graphics data.
            var softwareData:Vector.<IGraphicsData> = StaticInjectorContext.getInjector().getInstance(Graphic3D).softwareData;
            if(softwareData.length > 0)
            {
               map_.graphics.clear();
               map_.graphics.drawGraphicsData(softwareData);
               if(this.lastSoftwareClear)
               {
                  this.lastSoftwareClear = false;
               }
            }
            else if(!this.lastSoftwareClear)
            {
               map_.graphics.clear();
               this.lastSoftwareClear = true;
            }
            if(time % 149 == 0)
            {
               GraphicsFillExtra.manageSize();
            }
            FrameProfiler.end(FrameProfiler.GPU_SOFTWARE);
         }
         else
         {
            map_.graphics.clear();
            map_.graphics.drawGraphicsData(this.graphicsData_);
         }
         FrameProfiler.end(FrameProfiler.PRESENT);

         // draw filters
         this.map_.filters.length = 0;
         if(this.player_ != null && (this.player_.condition_ & ConditionEffect.MAP_FILTER_BITMASK) != 0)
         {
            var filters:Array = [];
            if(this.player_.isDrunk())
            {
               d = 20 + 10 * Math.sin(time / 1000);
               filters.push(new BlurFilter(d,d));
            }
            if(this.player_.isBlind())
            {
               filters.push(BLIND_FILTER);
            }
            this.map_.filters = filters;
         }
         else if(this.map_.filters.length > 0)
         {
            this.map_.filters = [];
         }

         FrameProfiler.begin(FrameProfiler.OVERLAYS);
         this.mapOverlay_.draw(camera,time);
         this.partyOverlay_.draw(camera,time);
         FrameProfiler.end(FrameProfiler.OVERLAYS);
      }
      private function getFilterIndex() : uint
      {
         var filterIndex:uint = 0;
         if(player_ != null && (player_.condition_ & ConditionEffect.MAP_FILTER_BITMASK) != 0)
         {
            if(player_.isBlind())
            {
               filterIndex = Renderer.STAGE3D_FILTER_BLIND;
            }
            else if(player_.isDrunk())
            {
               filterIndex = Renderer.STAGE3D_FILTER_DRUNK;
            }
         }
         return filterIndex;
      }
   }
}
