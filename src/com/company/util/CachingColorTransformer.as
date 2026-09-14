package com.company.util
{
   import flash.display.BitmapData;
   import flash.filters.BitmapFilter;
   import flash.geom.ColorTransform;
   import flash.geom.Point;
   import flash.utils.Dictionary;
   
   public class CachingColorTransformer
   {
      
      private static var bds_:Dictionary = new Dictionary();
      private static var alphas_:Dictionary = new Dictionary();
      // Strong BitmapData keys pin their sources, so the table stays bounded.
      // Mirrors TextureFactory.MAX_INDIVIDUAL/count.
      private static const MAX_ENTRIES:int = 1000;
      private static var cacheSize_:int = 0;
       
      
      public function CachingColorTransformer()
      {
         super();
      }
      
      public static function transformBitmapData(bitmapData:BitmapData, ct:ColorTransform) : BitmapData
      {
         var newBitmapData:BitmapData = null;
         var dict:Dictionary = bds_[bitmapData];
         if(dict != null)
         {
            newBitmapData = dict[ct];
         }
         else
         {
            dict = new Dictionary();
            bds_[bitmapData] = dict;
         }
         if(newBitmapData == null)
         {
            newBitmapData = bitmapData.clone();
            newBitmapData.colorTransform(newBitmapData.rect,ct);
            dict[ct] = newBitmapData;
            cacheSize_++;
            if(cacheSize_ > MAX_ENTRIES)
            {
               cacheSize_ -= evictEntries(cacheSize_ >> 1);
            }
         }
         return newBitmapData;
      }
      
      public static function filterBitmapData(bitmapData:BitmapData, filter:BitmapFilter) : BitmapData
      {
         var newBitmapData:BitmapData = null;
         var dict:Dictionary = bds_[bitmapData];
         if(dict != null)
         {
            newBitmapData = dict[filter];
         }
         else
         {
            dict = new Dictionary();
            bds_[bitmapData] = dict;
         }
         if(newBitmapData == null)
         {
            newBitmapData = bitmapData.clone();
            newBitmapData.applyFilter(newBitmapData,newBitmapData.rect,new Point(),filter);
            dict[filter] = newBitmapData;
            cacheSize_++;
            if(cacheSize_ > MAX_ENTRIES)
            {
               cacheSize_ -= evictEntries(cacheSize_ >> 1);
            }
         }
         return newBitmapData;
      }

      // Drops (without disposing) roughly the requested number of entries so the
      // table stays bounded. Values are NOT disposed here: cached outputs are
      // aliased by live draws, so disposal would corrupt them; unreferenced
      // bitmaps are reclaimed by GC once the strong keys are gone. Full dispose
      // happens in clear, when the map is being torn down. Returns removals.
      private static function evictEntries(target:int) : int
      {
         var removed:int = 0;
         var key:Object = null;
         var sub:Dictionary = null;
         var inner:Object = null;
         var probe:Object = null;
         var empty:Boolean = false;
         for(key in bds_)
         {
            sub = bds_[key];
            for(inner in sub)
            {
               delete sub[inner];
               removed++;
               if(removed >= target)
               {
                  break;
               }
            }
            empty = true;
            for(probe in sub)
            {
               empty = false;
               break;
            }
            if(empty)
            {
               delete bds_[key];
            }
            if(removed >= target)
            {
               break;
            }
         }
         return removed;
      }
      
      public static function alphaBitmapData(bitmapData:BitmapData, alpha:int) : BitmapData
      {
         var ct:ColorTransform = alphas_[alpha];
         if (ct == null) {
            ct = new ColorTransform(1, 1, 1, alpha / 100);
            alphas_[alpha] = ct;
         }
         return transformBitmapData(bitmapData,ct);
      }
      
      public static function clear() : void
      {
         var dict:Dictionary = null;
         var bd:BitmapData = null;
         for each(dict in bds_)
         {
            for each(bd in dict)
            {
               bd.dispose();
            }
         }
         bds_ = new Dictionary();
         alphas_ = new Dictionary();
         cacheSize_ = 0;
      }
   }
}
