package com.company.assembleegameclient.map
{
   import com.company.assembleegameclient.parameters.Parameters;
   import com.company.util.GraphicsUtil;
   import flash.display.GradientType;
   import flash.display.GraphicsGradientFill;
   import flash.display.GraphicsPath;
   import flash.display.IGraphicsData;
   import flash.display.Shape;
   
   public class GradientOverlay extends Shape
   {
      
      public function GradientOverlay()
      {
         super();
         this.drawOverlay();
         visible = false;
      }

      public function drawOverlay() : void
      {
         var viewH:Number = WebMain.sHeight / Parameters.data_.mscale;
         var gradientFill_:GraphicsGradientFill = new GraphicsGradientFill(GradientType.LINEAR,[0,0],[0,1],[0,255],GraphicsUtil.getGradientMatrix(10,viewH));
         var gradientPath_:GraphicsPath = GraphicsUtil.getRectPath(0,0,10,viewH);
         var gradientGraphicsData_:Vector.<IGraphicsData> = new <IGraphicsData>[gradientFill_,gradientPath_,GraphicsUtil.END_FILL];
         graphics.clear();
         graphics.drawGraphicsData(gradientGraphicsData_);
      }
   }
}
