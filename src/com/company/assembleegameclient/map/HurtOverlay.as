package com.company.assembleegameclient.map
{
   import com.company.assembleegameclient.parameters.Parameters;
   import com.company.util.GraphicsUtil;
   import flash.display.GradientType;
   import flash.display.GraphicsGradientFill;
   import flash.display.GraphicsPath;
   import flash.display.IGraphicsData;
   import flash.display.Shape;

   public class HurtOverlay extends Shape
   {


      private var gradientFill_:GraphicsGradientFill;

      private var gradientPath_:GraphicsPath;

      private var gradientGraphicsData_:Vector.<IGraphicsData>;

      public function HurtOverlay()
      {
         super();
         this.drawOverlay();
         visible = false;
      }

      public function drawOverlay() : void
      {
         var viewW:Number = WebMain.sWidth / Parameters.data_.mscale;
         var viewH:Number = WebMain.sHeight / Parameters.data_.mscale;
         var overlayW:Number = viewW - WebMain.hudWidth() / Parameters.data_.mscale;
         var fadeW:Number = overlayW / Math.sin(Math.PI / 4);
         var fadeH:Number = viewH / Math.sin(Math.PI / 4);
         this.gradientFill_ = new GraphicsGradientFill(GradientType.RADIAL,[16777215,16777215,16777215],[0,0,0.92],[0,155,255],GraphicsUtil.getGradientMatrix(fadeW,fadeH,0,(overlayW - fadeW) / 2,(viewH - fadeH) / 2));
         this.gradientPath_ = GraphicsUtil.getRectPath(0,0,viewW,viewH);
         this.gradientGraphicsData_ = new <IGraphicsData>[this.gradientFill_,this.gradientPath_,GraphicsUtil.END_FILL];
         graphics.clear();
         graphics.drawGraphicsData(this.gradientGraphicsData_);
      }
   }
}
