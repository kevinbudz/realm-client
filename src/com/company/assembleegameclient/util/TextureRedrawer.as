package com.company.assembleegameclient.util {
import com.company.assembleegameclient.util.redrawers.GlowRedrawer;
import com.company.util.AssetLibrary;
import com.company.util.PointUtil;

import flash.display.BitmapData;
import flash.display.Shader;
import flash.filters.BitmapFilterQuality;
import flash.filters.GlowFilter;
import flash.filters.ShaderFilter;
import flash.geom.ColorTransform;
import flash.geom.Matrix;
import flash.geom.Rectangle;
import flash.utils.ByteArray;
import flash.utils.Dictionary;

public class TextureRedrawer {

   public static const magic:int = 12;
   public static const minSize:int = (2 * magic);//24
   private static const BORDER:int = 4;
   public static const OUTLINE_FILTER:GlowFilter = new GlowFilter(0, 0.8, 1.4, 1.4, 0xFF, BitmapFilterQuality.LOW, false, false);

   private static var cache_:Dictionary = new Dictionary();
   private static var faceCache_:Dictionary = new Dictionary();
   private static var redrawCaches:Dictionary = new Dictionary();
   // Strong-keyed software caches: BitmapData keys pin their sources, so each
   // table stays bounded. Mirrors TextureFactory.MAX_INDIVIDUAL/count.
   private static const MAX_CACHE_ENTRIES:int = 1000;
   private static var cacheSize_:int = 0;
   private static var faceCacheSize_:int = 0;
   private static var redrawCacheSize_:int = 0;
   public static var sharedTexture_:BitmapData = null;
   private static var textureShaderEmbed_:Class = TextureRedrawer_textureShaderEmbed_;
   private static var textureShaderData_:ByteArray = (new textureShaderEmbed_() as ByteArray);
   private static var colorTexture1:BitmapData = new BitmapDataSpy(1, 1, false);
   private static var colorTexture2:BitmapData = new BitmapDataSpy(1, 1, false);


   public static function redraw(tex:BitmapData, size:int, padBottom:Boolean, glowColor:uint, useCache:Boolean = true, sMult:Number = 5):BitmapData {
      var hash:int = getHash(size, padBottom, glowColor, sMult);
      if (useCache && isCached(tex, hash)) {
         return redrawCaches[tex][hash];
      }
      var modTex:BitmapData = resize(tex, null, size, padBottom, 0, 0, sMult);
      modTex = GlowRedrawer.outlineGlow(modTex, glowColor, 1.4, useCache);
      if (useCache) {
         cache(tex, hash, modTex);
      }
      return modTex;
   }

   private static function getHash(size:int, padBottom:Boolean, glowColor:uint, sMult:Number):* {
      var h:int = (padBottom ? (1 << 27) : 0) | (size * sMult);
      if (glowColor == 0) {
         return h;
      }
      return h + glowColor;
   }

   private static function cache(tex:BitmapData, hash:*, modifiedTex:BitmapData):void {
      var sub:Object = redrawCaches[tex];
      if (sub == null) {
         sub = {};
         redrawCaches[tex] = sub;
      }
      if (!(hash in sub)) {
         redrawCacheSize_++;
      }
      sub[hash] = modifiedTex;
      if (redrawCacheSize_ > MAX_CACHE_ENTRIES) {
         redrawCacheSize_ -= evictEntries(redrawCaches, redrawCacheSize_ >> 1);
      }
   }

   // Drops (without disposing) roughly the requested number of entries from a
   // two-level (key -> key -> BitmapData) table. Values are NOT disposed here:
   // cached outputs are aliased by live draws and GameObject/Player texturing
   // caches, so disposal would corrupt them; unreferenced bitmaps are reclaimed
   // by GC once the strong keys are gone. Full dispose happens in clearCache,
   // when the map is being torn down. Returns the number of entries removed.
   private static function evictEntries(table:Dictionary, target:int):int {
      var removed:int = 0;
      var outer:Object = null;
      var sub:Object = null;
      var inner:Object = null;
      var probe:Object = null;
      var empty:Boolean = false;
      for (outer in table) {
         sub = table[outer];
         for (inner in sub) {
            delete sub[inner];
            removed++;
            if (removed >= target) {
               break;
            }
         }
         empty = true;
         for (probe in sub) {
            empty = false;
            break;
         }
         if (empty) {
            delete table[outer];
         }
         if (removed >= target) {
            break;
         }
      }
      return removed;
   }

   private static function isCached(tex:BitmapData, hash:int):Boolean {
      if (tex in redrawCaches) {
         if (hash in redrawCaches[tex]) {
            return true;
         }
      }
      return false;
   }

   public static function resize(tex:BitmapData, mask:BitmapData, size:int, padBottom:Boolean, op1:int, op2:int, sMult:Number = 5):BitmapData {
      if (mask != null && (op1 != 0 || op2 != 0)) {
         tex = retexture(tex, mask, op1, op2);
         size = size / 5;
      }
      var w:int = sMult * size / 100 * tex.width;
      var h:int = sMult * size / 100 * tex.height;
      var m:Matrix = new Matrix();
      m.scale(w / tex.width, h / tex.height);
      m.translate(magic, magic);
      var ret:BitmapData = new BitmapDataSpy(w + minSize, h + (padBottom ? magic : 1) + magic, true, 0);
      ret.draw(tex, m);
      return ret;
   }

   public static function redrawSolidSquare(color:uint, size:int):BitmapData {
      var colorDict:Dictionary = cache_[size];
      if (colorDict == null) {
         colorDict = new Dictionary();
         cache_[size] = colorDict;
      }
      var tex:BitmapData = colorDict[color];
      if (tex != null) {
         return tex;
      }
      tex = new BitmapDataSpy(size + 4 + 4, size + 4 + 4, true, 0);
      tex.fillRect(new Rectangle(4, 4, size, size), 0xFF000000 | color);
      tex.applyFilter(tex, tex.rect, PointUtil.ORIGIN, OUTLINE_FILTER);
      colorDict[color] = tex;
      cacheSize_++;
      if (cacheSize_ > MAX_CACHE_ENTRIES) {
         cacheSize_ -= evictEntries(cache_, cacheSize_ >> 1);
      }
      return tex;
   }

   public static function clearCache():void {
      var tex:BitmapData;
      var dict:Dictionary;
      var sub:Object;

      for each (dict in cache_) {
         for each (tex in dict) {
            tex.dispose();
         }
      }
      cache_ = new Dictionary();
      cacheSize_ = 0;

      for each (dict in faceCache_) {
         for each (tex in dict) {
            tex.dispose();
         }
      }
      faceCache_ = new Dictionary();
      faceCacheSize_ = 0;

      // redrawCaches used to be skipped here, pinning every resized texture
      // for the rest of the session via strong BitmapData keys. Dispose and
      // drop it like the other tables.
      for each (sub in redrawCaches) {
         for each (tex in sub) {
            tex.dispose();
         }
      }
      redrawCaches = new Dictionary();
      redrawCacheSize_ = 0;

      // GlowRedrawer outputs feed redraw(), and its table is keyed by those
      // same BitmapDatas, so it must be cleared together with this cache.
      GlowRedrawer.clearCache();
   }

   public static function redrawFace(tex:BitmapData, shade:Number):BitmapData {
      if (shade == 1) {
         return tex;
      }
      var shadeInt:int = int(shade * 100);
      var dict:Dictionary = faceCache_[shadeInt];
      if (dict == null) {
         dict = new Dictionary();
         faceCache_[shadeInt] = dict;
      }
      var modTex:BitmapData = dict[tex];
      if (modTex != null) {
         return modTex;
      }
      modTex = tex.clone();
      modTex.colorTransform(modTex.rect, new ColorTransform(shade, shade, shade));
      dict[tex] = modTex;
      faceCacheSize_++;
      if (faceCacheSize_ > MAX_CACHE_ENTRIES) {
         faceCacheSize_ -= evictEntries(faceCache_, faceCacheSize_ >> 1);
      }
      return modTex;
   }

   private static function getTexture(op:int, bmp:BitmapData):BitmapData {
      var ret:BitmapData;
      var type:int = (op >> 24) & 0xFF;
      var value:uint = op & 0xFFFFFF; // could mean color or sprite index
      switch (type) {
         case 0:
            ret = bmp;
            break;
         case 1:
            bmp.setPixel(0, 0, value);
            ret = bmp;
            break;
         case 4:
            ret = AssetLibrary.getImageFromSet("textile4x4", value);
            break;
         case 5:
            ret = AssetLibrary.getImageFromSet("textile5x5", value);
            break;
         case 9:
            ret = AssetLibrary.getImageFromSet("textile9x9", value);
            break;
         case 10:
            ret = AssetLibrary.getImageFromSet("textile10x10", value);
            break;
         case 0xFF:
            ret = sharedTexture_;
            break;
         default:
            ret = bmp;
      }
      return ret;
   }

   private static function retexture(tex:BitmapData, mask:BitmapData, op1:int, op2:int):BitmapData {
      var m:Matrix = new Matrix();
      m.scale(5, 5);
      var ret:BitmapData = new BitmapDataSpy(tex.width * 5, tex.height * 5, true, 0);
      ret.draw(tex, m);
      var c1:BitmapData = getTexture(op1, colorTexture1);
      var c2:BitmapData = getTexture(op2, colorTexture2);
      var shader:Shader = new Shader(textureShaderData_);
      shader.data.src.input = ret;
      shader.data.mask.input = mask;
      shader.data.texture1.input = c1;
      shader.data.texture2.input = c2;
      shader.data.texture1Size.value = [op1 == 0 ? 0 : c1.width];
      shader.data.texture2Size.value = [op2 == 0 ? 0 : c2.width];
      ret.applyFilter(ret, ret.rect, PointUtil.ORIGIN, new ShaderFilter(shader));
      return ret;
   }

   private static function getDrawMatrix():Matrix {
      var m:Matrix = new Matrix();
      m.scale(8, 8);
      m.translate(BORDER, BORDER);
      return m;
   }


}
}
