package com.company.assembleegameclient.objects
{
import com.company.assembleegameclient.engine3d.ObjectFace3D;
import com.company.assembleegameclient.parameters.Parameters;
import flash.display.BitmapData;
import flash.geom.Vector3D;
import kabam.rotmg.stage3D.GraphicsFillExtra;

public class CaveWall extends ConnectedObject
{


   public function CaveWall(objectXML:XML)
   {
      super(objectXML);
   }

   override protected function buildDot() : void
   {
      var v0:Vector3D = new Vector3D(-0.25 - Math.random() * 0.25,-0.25 - Math.random() * 0.25,0);
      var v1:Vector3D = new Vector3D(0.25 + Math.random() * 0.25,-0.25 - Math.random() * 0.25,0);
      var v2:Vector3D = new Vector3D(0.25 + Math.random() * 0.25,0.25 + Math.random() * 0.25,0);
      var v3:Vector3D = new Vector3D(-0.25 - Math.random() * 0.25,0.25 + Math.random() * 0.25,0);
      var v4:Vector3D = new Vector3D(-0.25 + Math.random() * 0.5,-0.25 + Math.random() * 0.5,1);
      this.faceHelper(null,texture_,v4,v0,v1);
      this.faceHelper(null,texture_,v4,v1,v2);
      this.faceHelper(null,texture_,v4,v2,v3);
      this.faceHelper(null,texture_,v4,v3,v0);
   }

   override protected function buildShortLine() : void
   {
      var v0:Vector3D = this.getVertex(0,0);
      var v1:Vector3D = this.getVertex(0,3);
      var v2:Vector3D = new Vector3D(0.25 + Math.random() * 0.25,0.25 + Math.random() * 0.25,0);
      var v3:Vector3D = new Vector3D(-0.25 - Math.random() * 0.25,0.25 + Math.random() * 0.25,0);
      var v4:Vector3D = this.getVertex(0,1);
      var v5:Vector3D = this.getVertex(0,2);
      var v6:Vector3D = new Vector3D(Math.random() * 0.25,Math.random() * 0.25,0.5);
      var v7:Vector3D = new Vector3D(Math.random() * -0.25,Math.random() * 0.25,0.5);
      this.faceHelper(null,texture_,v4,v7,v3,v0);
      this.faceHelper(null,texture_,v7,v6,v2,v3);
      this.faceHelper(null,texture_,v6,v5,v1,v2);
      this.faceHelper(null,texture_,v4,v5,v6,v7);
   }

   override protected function buildL() : void
   {
      var v0:Vector3D = this.getVertex(0,0);
      var v1:Vector3D = this.getVertex(0,3);
      var v2:Vector3D = this.getVertex(1,0);
      var v3:Vector3D = this.getVertex(1,3);
      var v4:Vector3D = new Vector3D(-Math.random() * 0.25,Math.random() * 0.25,0);
      var v5:Vector3D = this.getVertex(0,1);
      var v6:Vector3D = this.getVertex(0,2);
      var v7:Vector3D = this.getVertex(1,1);
      var v8:Vector3D = this.getVertex(1,2);
      var v9:Vector3D = new Vector3D(Math.random() * 0.25,-Math.random() * 0.25,1);
      this.faceHelper(null,texture_,v5,v9,v4,v0);
      this.faceHelper(null,texture_,v9,v8,v3,v4);
      this.faceHelper(N2,texture_,v7,v6,v1,v2);
      this.faceHelper(null,texture_,v5,v6,v7,v8,v9);
   }

   override protected function buildLine() : void
   {
      var v0:Vector3D = this.getVertex(0,0);
      var v1:Vector3D = this.getVertex(0,3);
      var v2:Vector3D = this.getVertex(2,3);
      var v3:Vector3D = this.getVertex(2,0);
      var v4:Vector3D = this.getVertex(0,1);
      var v5:Vector3D = this.getVertex(0,2);
      var v6:Vector3D = this.getVertex(2,2);
      var v7:Vector3D = this.getVertex(2,1);
      this.faceHelper(N7,texture_,v4,v7,v3,v0);
      this.faceHelper(N3,texture_,v6,v5,v1,v2);
      this.faceHelper(null,texture_,v4,v5,v6,v7);
   }

   override protected function buildT() : void
   {
      var v0:Vector3D = this.getVertex(0,0);
      var v1:Vector3D = this.getVertex(0,3);
      var v2:Vector3D = this.getVertex(1,0);
      var v3:Vector3D = this.getVertex(1,3);
      var v4:Vector3D = this.getVertex(3,3);
      var v5:Vector3D = this.getVertex(3,0);
      var v6:Vector3D = this.getVertex(0,1);
      var v7:Vector3D = this.getVertex(0,2);
      var v8:Vector3D = this.getVertex(1,1);
      var v9:Vector3D = this.getVertex(1,2);
      var va:Vector3D = this.getVertex(3,2);
      var vb:Vector3D = this.getVertex(3,1);
      this.faceHelper(N2,texture_,v8,v7,v1,v2);
      this.faceHelper(null,texture_,va,v9,v3,v4);
      this.faceHelper(N0,texture_,v6,vb,v5,v0);
      this.faceHelper(null,texture_,v6,v7,v8,v9,va,vb);
   }

   override protected function buildCross() : void
   {
      var v0:Vector3D = this.getVertex(0,0);
      var v1:Vector3D = this.getVertex(0,3);
      var v2:Vector3D = this.getVertex(1,0);
      var v3:Vector3D = this.getVertex(1,3);
      var v4:Vector3D = this.getVertex(2,3);
      var v5:Vector3D = this.getVertex(2,0);
      var v6:Vector3D = this.getVertex(3,3);
      var v7:Vector3D = this.getVertex(3,0);
      var v8:Vector3D = this.getVertex(0,1);
      var v9:Vector3D = this.getVertex(0,2);
      var va:Vector3D = this.getVertex(1,1);
      var vb:Vector3D = this.getVertex(1,2);
      var vc:Vector3D = this.getVertex(2,2);
      var vd:Vector3D = this.getVertex(2,1);
      var ve:Vector3D = this.getVertex(3,2);
      var vf:Vector3D = this.getVertex(3,1);
      this.faceHelper(N2,texture_,va,v9,v1,v2);
      this.faceHelper(N4,texture_,vc,vb,v3,v4);
      this.faceHelper(N6,texture_,ve,vd,v5,v6);
      this.faceHelper(N0,texture_,v8,vf,v7,v0);
      this.faceHelper(null,texture_,v8,v9,va,vb,vc,vd,ve,vf);
   }

   protected function getVertex(side:int, id:int) : Vector3D
   {
      var r:int = 0;
      var v:Number = NaN;
      var h:Number = NaN;
      var x:int = x_;
      var y:int = y_;
      var rside:int = (side + rotation_) % 4;
      switch(rside)
      {
         case 1:
            x++;
            break;
         case 2:
            y++;
      }
      switch(id)
      {
         case 0:
         case 3:
            r = 15 + (x * 1259 ^ y * 2957) % 35;
            break;
         case 1:
         case 2:
            r = 3 + (x * 2179 ^ y * 1237) % 35;
      }
      switch(id)
      {
         case 0:
            v = -r / 100;
            h = 0;
            break;
         case 1:
            v = -r / 100;
            h = 1;
            break;
         case 2:
            v = r / 100;
            h = 1;
            break;
         case 3:
            v = r / 100;
            h = 0;
      }
      switch(side)
      {
         case 0:
            return new Vector3D(v,-0.5,h);
         case 1:
            return new Vector3D(0.5,v,h);
         case 2:
            return new Vector3D(v,0.5,h);
         case 3:
            return new Vector3D(-0.5,v,h);
         default:
            return null;
      }
   }

   protected function faceHelper(normalL:Vector3D, texture:BitmapData, ... args) : void
   {
      var v:Vector3D = null;
      var oldLen:int = 0;
      var i:int = 0;
      var offset:int = obj3D_.vL_.length / 3;
      for each(v in args)
      {
         obj3D_.vL_.push(v.x,v.y,v.z);
      }
      oldLen = obj3D_.faces_.length;
      if(args.length == 4)
      {
         obj3D_.uvts_.push(0,0,0,1,0,0,1,1,0,0,1,0);
         if(Math.random() < 0.5)
         {
            obj3D_.faces_.push(new ObjectFace3D(obj3D_,new <int>[offset,offset + 1,offset + 3]),new ObjectFace3D(obj3D_,new <int>[offset + 1,offset + 2,offset + 3]));
         }
         else
         {
            obj3D_.faces_.push(new ObjectFace3D(obj3D_,new <int>[offset,offset + 2,offset + 3]),new ObjectFace3D(obj3D_,new <int>[offset,offset + 1,offset + 2]));
         }
      }
      else if(args.length == 3)
      {
         obj3D_.uvts_.push(0,0,0,0,1,0,1,1,0);
         obj3D_.faces_.push(new ObjectFace3D(obj3D_,new <int>[offset,offset + 1,offset + 2]));
      }
      else if(args.length == 5)
      {
         obj3D_.uvts_.push(0.2,0,0,0.8,0,0,1,0.2,0,1,0.8,0,0,0.8,0);
         obj3D_.faces_.push(new ObjectFace3D(obj3D_,new <int>[offset,offset + 1,offset + 2,offset + 3,offset + 4]));
      }
      else if(args.length == 6)
      {
         obj3D_.uvts_.push(0,0,0,0.2,0,0,1,0.2,0,1,0.8,0,0,0.8,0,0,0.2,0);
         obj3D_.faces_.push(new ObjectFace3D(obj3D_,new <int>[offset,offset + 1,offset + 2,offset + 3,offset + 4,offset + 5]));
      }
      else if(args.length == 8)
      {
         obj3D_.uvts_.push(0,0,0,0.2,0,0,1,0.2,0,1,0.8,0,0.8,1,0,0.2,1,0,0,0.8,0,0,0.2,0);
         obj3D_.faces_.push(new ObjectFace3D(obj3D_,new <int>[offset,offset + 1,offset + 2,offset + 3,offset + 4,offset + 5,offset + 6,offset + 7]));
      }
      if(normalL != null || texture != null)
      {
         for(i = oldLen; i < obj3D_.faces_.length; i++)
         {
            obj3D_.faces_[i].normalL_ = normalL;
            obj3D_.faces_[i].texture_ = texture;
         }
      }
      if(Parameters.GPURenderFrame)
      {
         this.bakeGPUFaces(oldLen);
      }
   }

   // GPU static geometry for the faces just built [oldLen, end): triangles bake one
   // degenerate-quad VB each; N-gons are ear-clipped (triangulateFace) into triangle
   // faces first, so every wall piece draws via CMD_QUAD and no software triple
   // survives to force the display-list blit. Software-mode builds are untouched.
   private function bakeGPUFaces(oldLen:int) : void
   {
      var faces:Vector.<ObjectFace3D> = obj3D_.faces_;
      var end:int = faces.length;
      var grown:Vector.<ObjectFace3D> = new Vector.<ObjectFace3D>();
      var dropped:Vector.<ObjectFace3D> = new Vector.<ObjectFace3D>();
      for(var i:int = oldLen; i < end; i++)
      {
         var face:ObjectFace3D = faces[i];
         if(GraphicsFillExtra.getVertexBuffer(face.bitmapFill_) != null)
         {
            continue;
         }
         if(face.indices_.length == 3)
         {
            this.bakeTriVB(face,face.indices_[0],face.indices_[1],face.indices_[2]);
            continue;
         }
         var n:int = face.indices_.length;
         var fu:Vector.<Number> = new Vector.<Number>();
         var fv:Vector.<Number> = new Vector.<Number>();
         for(var k:int = 0; k < n; k++)
         {
            fu.push(obj3D_.uvts_[face.indices_[k] * 3]);
            fv.push(obj3D_.uvts_[face.indices_[k] * 3 + 1]);
         }
         var tris:Vector.<int> = triangulateFace(fu,fv);
         for(var t:int = 0; t < tris.length; t += 3)
         {
            var nf:ObjectFace3D = new ObjectFace3D(obj3D_,new <int>[face.indices_[tris[t]],face.indices_[tris[t + 1]],face.indices_[tris[t + 2]]]);
            nf.normalL_ = face.normalL_;
            nf.texture_ = face.texture_;
            grown.push(nf);
            this.bakeTriVB(nf,nf.indices_[0],nf.indices_[1],nf.indices_[2]);
         }
         dropped.push(face);
      }
      if(dropped.length != 0)
      {
         var kept:Vector.<ObjectFace3D> = new Vector.<ObjectFace3D>();
         for each(var f:ObjectFace3D in faces)
         {
            if(dropped.indexOf(f) == -1)
            {
               kept.push(f);
            }
         }
         obj3D_.faces_ = kept;
      }
      for each(var g:ObjectFace3D in grown)
      {
         obj3D_.faces_.push(g);
      }
   }

   // Bakes one triangle's static vertex buffer. Positions live in texture-fraction
   // space (equal to the face's own uvts_, so the per-frame tToS maps them onto
   // exactly the 2D path's screen verts); z stays 0 like every sprite quad and uvs
   // sample the same texels. The 4th slot duplicates the 3rd (degenerate) for the
   // shared quad index buffer. Registering a VB also marks hasExtras, routing the
   // face to CMD_QUAD instead of the batcher (which can only draw rectangles).
   private function bakeTriVB(face:ObjectFace3D, g0:int, g1:int, g2:int) : void
   {
      var uv:Vector.<Number> = obj3D_.uvts_;
      var u0:Number = uv[g0 * 3];
      var v0:Number = uv[g0 * 3 + 1];
      var u1:Number = uv[g1 * 3];
      var v1:Number = uv[g1 * 3 + 1];
      var u2:Number = uv[g2 * 3];
      var v2:Number = uv[g2 * 3 + 1];
      GraphicsFillExtra.setVertexBuffer(face.bitmapFill_,Vector.<Number>([u0,v0,0,u0,v0,u1,v1,0,u1,v1,u2,v2,0,u2,v2,u2,v2,0,u2,v2]));
   }

   // Ear-clipping triangulation over the face's own (u,v) parametrization (uvts_
   // layouts are compile-time constants, simple by design; validated offline over
   // all arities plus fuzz). Returns flat index triples into the vertex order.
   // Exact for simple polygons: shared verts project identically, culling runs
   // with triangle culling off, so the union matches the N-gon pixel-for-pixel.
   private static function triangulateFace(u:Vector.<Number>, v:Vector.<Number>) : Vector.<int>
   {
      var n:int = u.length;
      var out:Vector.<int> = new Vector.<int>();
      var i:int = 0;
      var j:int = 0;
      if(n == 3)
      {
         out.push(0,1,2);
         return out;
      }
      var area:Number = 0;
      for(i = 0; i < n; i++)
      {
         j = i + 1 < n ? i + 1 : 0;
         area += u[i] * v[j] - u[j] * v[i];
      }
      var live:Vector.<int> = new Vector.<int>();
      if(area < 0)
      {
         for(i = n - 1; i >= 0; i--)
         {
            live.push(i);
         }
      }
      else
      {
         for(i = 0; i < n; i++)
         {
            live.push(i);
         }
      }
      var guard:int = 0;
      var m:int = 0;
      var k:int = 0;
      var p:int = 0;
      var c:int = 0;
      var nx:int = 0;
      var cr:Number = 0;
      var blocked:Boolean = false;
      var found:Boolean = false;
      while(live.length > 3 && guard < 100)
      {
         guard++;
         found = false;
         m = live.length;
         for(k = 0; k < m; k++)
         {
            p = live[(k + m - 1) % m];
            c = live[k];
            nx = live[(k + 1) % m];
            cr = (u[c] - u[p]) * (v[nx] - v[c]) - (v[c] - v[p]) * (u[nx] - u[c]);
            if(cr <= -0.000000001)
            {
               continue;
            }
            blocked = false;
            for each(var q:int in live)
            {
               if(q == p || q == c || q == nx)
               {
                  continue;
               }
               if(pointInTri(u[q],v[q],u[p],v[p],u[c],v[c],u[nx],v[nx]))
               {
                  blocked = true;
                  break;
               }
            }
            if(!blocked)
            {
               out.push(p,c,nx);
               live.splice(k,1);
               found = true;
               break;
            }
         }
         if(!found)
         {
            break;
         }
      }
      if(live.length == 3)
      {
         out.push(live[0],live[1],live[2]);
      }
      else
      {
         for(var f:int = 1; f < live.length - 1; f++)
         {
            out.push(live[0],live[f],live[f + 1]);
         }
      }
      return out;
   }

   private static function pointInTri(px:Number, py:Number, ax:Number, ay:Number, bx:Number, by:Number, cx:Number, cy:Number) : Boolean
   {
      var d:Number = (by - cy) * (ax - cx) + (cx - bx) * (ay - cy);
      if(d > -0.000000000001 && d < 0.000000000001)
      {
         return false;
      }
      var l1:Number = ((by - cy) * (px - cx) + (cx - bx) * (py - cy)) / d;
      var l2:Number = ((cy - ay) * (px - cx) + (ax - cx) * (py - cy)) / d;
      var l3:Number = 1 - l1 - l2;
      return l1 > 0.000000001 && l2 > 0.000000001 && l3 > 0.000000001;
   }
}
}
