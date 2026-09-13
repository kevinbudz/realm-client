package com.company.assembleegameclient.map
{
import com.company.assembleegameclient.engine3d.Face3D;
import com.company.assembleegameclient.parameters.Parameters;
import flash.display.BitmapData;
import flash.display.IGraphicsData;
import kabam.rotmg.stage3D.GraphicsFillExtra;

public class SquareFace
{


   public var animate_:int;

   public var face_:Face3D;

   public var xOffset_:Number = 0;

   public var yOffset_:Number = 0;

   public var animateDx_:Number = 0;

   public var animateDy_:Number = 0;

   // Static-tile fast path (see draw): a face with NO_ANIMATE produces byte-identical
   // uvt_ and shader offsets every frame, so after the first full draw both can be
   // skipped. uvtGpu_ tracks which render mode uvt_ was baked for: GPU mode zeroes the
   // baked offsets (scroll moves to the shader constant), software mode bakes them in,
   // so a live GPU/software flip must rebuild once. offsetGen_ guards the same skip
   // against the offset table being discarded by GraphicsFillExtra.manageSize.
   private var uvtInit_:Boolean = false;
   private var uvtGpu_:Boolean = false;
   private var offsetU_:Number = 0;
   private var offsetV_:Number = 0;
   private var offsetGen_:int = -1;

   public function SquareFace(texture:BitmapData, vin:Vector.<Number>, xOffset:Number, yOffset:Number, animate:int, animateDx:Number, animateDy:Number)
   {
      super();
      this.face_ = new Face3D(texture,vin,Square.UVT.concat());
      this.xOffset_ = xOffset;
      this.yOffset_ = yOffset;
      if(this.xOffset_ != 0 || this.yOffset_ != 0)
      {
         this.face_.bitmapFill_.repeat = true;
      }
      this.animate_ = animate;
      if(this.animate_ != AnimateProperties.NO_ANIMATE)
      {
         this.face_.bitmapFill_.repeat = true;
      }
      this.animateDx_ = animateDx;
      this.animateDy_ = animateDy;
   }

   public function dispose() : void
   {
      this.face_.dispose();
      this.face_ = null;
   }

   public function draw(graphicsData:Vector.<IGraphicsData>, camera:Camera, time:int) : Boolean
   {
      var xOffset:Number = NaN;
      var yOffset:Number = NaN;
      var animated:Boolean = this.animate_ != AnimateProperties.NO_ANIMATE;
      var gpu:Boolean = Parameters.GPURenderFrame;
      if(animated)
      {
         switch(this.animate_)
         {
            case AnimateProperties.WAVE_ANIMATE:
               xOffset = this.xOffset_ + Math.sin(this.animateDx_ * time / 1000);
               yOffset = this.yOffset_ + Math.sin(this.animateDy_ * time / 1000);
               break;
            case AnimateProperties.FLOW_ANIMATE:
               xOffset = this.xOffset_ + this.animateDx_ * time / 1000;
               yOffset = this.yOffset_ + this.animateDy_ * time / 1000;
         }
      }
      else
      {
         xOffset = this.xOffset_;
         yOffset = this.yOffset_;
      }
      if(gpu)
      {
         // Static offsets are written once; a table discard (offsetGen_) forces a resend.
         if(animated || this.offsetGen_ != GraphicsFillExtra.offsetEpoch
            || xOffset != this.offsetU_ || yOffset != this.offsetV_)
         {
            GraphicsFillExtra.setOffsetUV(this.face_.bitmapFill_,xOffset,yOffset);
            this.offsetU_ = xOffset;
            this.offsetV_ = yOffset;
            this.offsetGen_ = GraphicsFillExtra.offsetEpoch;
         }
         xOffset = yOffset = 0;
      }
      else
      {
         this.offsetGen_ = -1;
      }
      // Static faces rebuild identical uvt_ every frame; worse, setUVT re-arms the
      // texture-matrix regen, so skipping it also skips a redundant matrix solve.
      // Rebuild on first draw and after any GPU/software flip (baked offsets differ).
      if(animated || !this.uvtInit_ || this.uvtGpu_ != gpu)
      {
         this.face_.uvt_.length = 0;
         this.face_.uvt_.push(xOffset,yOffset,0,1 + xOffset,yOffset,0,1 + xOffset,1 + yOffset,0,xOffset,1 + yOffset,0);
         this.face_.setUVT(this.face_.uvt_);
         this.uvtInit_ = true;
         this.uvtGpu_ = gpu;
      }
      return this.face_.draw(graphicsData,camera);
   }
}
}
