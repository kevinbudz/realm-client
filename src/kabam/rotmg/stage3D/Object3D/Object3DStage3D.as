package kabam.rotmg.stage3D.Object3D
{
   import flash.display.BitmapData;
   import flash.display3D.Context3D;
   import flash.display3D.Context3DProgramType;
   import flash.display3D.Context3DTextureFormat;
   import flash.display3D.Context3DVertexBufferFormat;
   import flash.display3D.Program3D;
   import flash.display3D.textures.Texture;
   import flash.geom.Matrix3D;
   import flash.geom.Vector3D;
   import kabam.rotmg.stage3D.graphic3D.TextureFactory;
   
   public class Object3DStage3D
   {
      
      public static const missingTextureBitmap:BitmapData = new BitmapData(1,1,true,2290649343);
       
      
      public var model_:Model3D_stage3d = null;
      
      private var bitmapData:BitmapData;
      
      public var modelMatrix_:Matrix3D;
      
      public var modelView_:Matrix3D;
      
      public var modelViewProjection_:Matrix3D;
      
      public var position:Vector3D;
      
      private var zRotation_:Number;
      
      private var texture_:Texture;
      
      public var color_:uint = 16777215;
      
      // (r, g, b, 1) in 0..1 for the solid-fill fragment program (fc0)
      private var colorConstants_:Vector.<Number> = new <Number>[1,1,1,1];
      
      public function Object3DStage3D(model:Model3D_stage3d)
      {
         super();
         this.model_ = model;
         this.modelMatrix_ = new Matrix3D();
         this.modelView_ = new Matrix3D();
         this.modelViewProjection_ = new Matrix3D();
      }
      
      public function setBitMapData(bitmap:BitmapData) : void
      {
         this.bitmapData = TextureFactory.GetFlippedBitmapData(bitmap);
      }
      
      public function setPosition(x:Number, y:Number, z:Number, angleDegrees:Number) : void
      {
         this.position = new Vector3D(x,y,z);
         this.zRotation_ = angleDegrees;
      }
      
      public function dispose() : void
      {
         if(this.texture_ != null)
         {
            this.texture_.dispose();
            this.texture_ = null;
         }
         this.bitmapData = null;
         this.modelMatrix_ = null;
         this.modelView_ = null;
         this.modelViewProjection_ = null;
         this.position = null;
         this.colorConstants_ = null;
      }
      
      public function UpdateModelMatrix() : void
      {
         this.modelMatrix_.identity();
         this.modelMatrix_.appendRotation(this.zRotation_,Vector3D.Z_AXIS);
         this.modelMatrix_.appendTranslation(this.position.x,this.position.y,this.position.z);
      }
      
      public function GetModelMatrix() : Matrix3D
      {
         return this.modelMatrix_;
      }
      
      public function setColor(color:uint) : void
      {
         this.color_ = color;
         this.colorConstants_[0] = ((color >> 16) & 255) / 255;
         this.colorConstants_[1] = ((color >> 8) & 255) / 255;
         this.colorConstants_[2] = (color & 255) / 255;
      }
      
      /**
       * Draws the model, matching the software ObjectFace3D.draw material rules:
       *  - textured groups sample the object sprite and multiply by the per-face shade
       *  - Solid* groups (or any group when the object has no sprite) are a flat
       *    props_.color_ multiplied by the same shade.
       * Programs are expected to already have vc0 (MVP), vc8 (model), vc12 (light) and
       * vc13 (shade constants) set; this only switches program / texture / fc0 per group.
       */
      public function draw(context:Context3D, texturedProgram:Program3D, solidProgram:Program3D) : void
      {
         var group:OBJGroup = null;
         var useSolid:Boolean = false;
         var currentSolid:int = -1;
         context.setVertexBufferAt(0,this.model_.vertexBuffer,0,Context3DVertexBufferFormat.FLOAT_3);
         context.setVertexBufferAt(1,this.model_.vertexBuffer,3,Context3DVertexBufferFormat.FLOAT_3);
         context.setVertexBufferAt(2,this.model_.vertexBuffer,6,Context3DVertexBufferFormat.FLOAT_2);
         var hasSprite:Boolean = this.bitmapData != null;
         if(this.texture_ == null && hasSprite)
         {
            this.texture_ = context.createTexture(this.bitmapData.width,this.bitmapData.height,Context3DTextureFormat.BGRA,false);
            this.texture_.uploadFromBitmapData(this.bitmapData);
         }
         for each(group in this.model_.groups)
         {
            if(group.indexBuffer == null)
            {
               continue;
            }
            useSolid = group.isSolid || !hasSprite;
            if(int(useSolid) != currentSolid)
            {
               currentSolid = int(useSolid);
               if(useSolid)
               {
                  context.setProgram(solidProgram);
                  context.setTextureAt(0,null);
                  context.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT,0,this.colorConstants_);
               }
               else
               {
                  context.setProgram(texturedProgram);
                  context.setTextureAt(0,this.texture_);
               }
            }
            context.drawTriangles(group.indexBuffer);
         }
      }
   }
}
