package com.company.assembleegameclient.util
{
   import com.company.assembleegameclient.parameters.Parameters;
   import com.company.ui.SimpleText;
   import flash.display.Sprite;
   import flash.events.Event;
   import flash.events.MouseEvent;
   import flash.filters.GlowFilter;

   /**
    * On-screen readout for FrameProfiler. Enables the profiler while on stage and disables it
    * when removed, so there's zero cost when the overlay is hidden.
    *
    * Single column layout: frame, then scene. Frame nests script and render as
    * collapsible sub-groups, all sharing one look: bold label, value, arrow on the
    * right. Click a header row to toggle it. Detail rows use a bold key column
    * with values lined up in a second column.
    *
    * Accounting (every level sums): all instrumented sections run inside the
    * enterFrame handler, i.e. inside avgScript. "script" is the non-draw CPU
    * (update + hud + other); "render" is the draw phases plus idle, where idle
    * is the vsync/idle gap outside the handler (avgFrame - avgScript). So
    * frame = script + render. Parenthesized GPU rows are subsets already
    * counted in a parent (inside PRESENT, or inside GPU_SCENE) and are not added.
    */
   public class FrameProfilerView extends Sprite
   {
      private static const GROUP_FRAME:int = 0;
      private static const GROUP_SCRIPT:int = 1;
      private static const GROUP_RENDER:int = 2;
      private static const GROUP_SCENE:int = 3;
      private static const GROUP_COUNT:int = 4;

      private static const ARROW_SIZE:Number = 8;
      private static const ARROW_GAP:Number = 4;
      private static const COL_GAP:Number = 8;
      private static const BODY_INDENT:Number = 12;
      private static const ROW_TIGHTEN:Number = 2;

      // Top-level, non-overlapping draw phases. These sum to the draw portion of render.
      private static const RENDER_TOP_SECTIONS:Vector.<int> = new <int>[FrameProfiler.TILES,FrameProfiler.COLLECT,FrameProfiler.SORT,
         FrameProfiler.DRAW_UNDER,FrameProfiler.SHADOWS,FrameProfiler.DRAW_OBJECTS,FrameProfiler.TOP_TILES,
         FrameProfiler.PRESENT,FrameProfiler.OVERLAYS];
      // Subsets already counted in a parent, shown in parentheses and never added:
      // GPU_SCENE/GPU_SWAP/GPU_SOFTWARE run inside PRESENT, GPU_BUILD/GPU_ATLAS/GPU_DRAW inside GPU_SCENE.
      private static const RENDER_SUB_SECTIONS:Vector.<int> = new <int>[FrameProfiler.GPU_SCENE,FrameProfiler.GPU_SWAP,
         FrameProfiler.GPU_SOFTWARE,FrameProfiler.GPU_BUILD,FrameProfiler.GPU_ATLAS,FrameProfiler.GPU_DRAW];

      private var headerKey_:SimpleText;
      private var headerVal_:SimpleText;
      private var heads_:Vector.<Sprite> = new Vector.<Sprite>(GROUP_COUNT,true);
      private var headLabels_:Vector.<SimpleText> = new Vector.<SimpleText>(GROUP_COUNT,true);
      private var headVals_:Vector.<SimpleText> = new Vector.<SimpleText>(GROUP_COUNT,true);
      private var headArrows_:Vector.<Sprite> = new Vector.<Sprite>(GROUP_COUNT,true);
      private var bodies_:Vector.<Sprite> = new Vector.<Sprite>(GROUP_COUNT,true);
      // Body rows are per-row sprites (key + value) on a fixed two-column grid with one
      // uniform row height, so key/value lines can never drift apart vertically down a list.
      private static const MAX_BODY_ROWS:int = 20;
      private var bodyRows_:Vector.<Sprite> = new Vector.<Sprite>(GROUP_COUNT * MAX_BODY_ROWS,true);
      private var bodyRowKeys_:Vector.<SimpleText> = new Vector.<SimpleText>(GROUP_COUNT * MAX_BODY_ROWS,true);
      private var bodyRowVals_:Vector.<SimpleText> = new Vector.<SimpleText>(GROUP_COUNT * MAX_BODY_ROWS,true);
      private var expanded_:Vector.<Boolean> = new <Boolean>[true,true,true,false];
      private var atlas_:SimpleText;
      private var lastSerial_:int = -1;

      public function FrameProfilerView()
      {
         super();
         this.headerKey_ = makeText(true);
         addChild(this.headerKey_);
         this.headerVal_ = makeText(false);
         addChild(this.headerVal_);

         for(var g:int = 0; g < GROUP_COUNT; g++)
         {
            var head:Sprite = new Sprite();
            var arrow:Sprite = makeArrow();
            head.addChild(arrow);
            var label:SimpleText = makeText(true);
            head.addChild(label);
            var val:SimpleText = makeText(false);
            head.addChild(val);
            head.buttonMode = true;
            head.mouseChildren = false;
            head.addEventListener(MouseEvent.CLICK,makeToggle(g));
            addChild(head);
            this.heads_[g] = head;
            this.headArrows_[g] = arrow;
            this.headLabels_[g] = label;
            this.headVals_[g] = val;

            var body:Sprite = new Sprite();
            addChild(body);
            this.bodies_[g] = body;
            var base:int = g * MAX_BODY_ROWS;
            for(var r:int = 0; r < MAX_BODY_ROWS; r++)
            {
               var row:Sprite = new Sprite();
               var rowKey:SimpleText = makeText(true);
               row.addChild(rowKey);
               var rowVal:SimpleText = makeText(false);
               row.addChild(rowVal);
               // Not added to body here: setBody adds only the rows it needs, since
               // hidden children would still inflate the body's measured height.
               this.bodyRows_[base + r] = row;
               this.bodyRowKeys_[base + r] = rowKey;
               this.bodyRowVals_[base + r] = rowVal;
            }
         }

         this.atlas_ = makeText(false);
         addChild(this.atlas_);

         addEventListener(Event.ADDED_TO_STAGE,this.onAddedToStage);
         addEventListener(Event.REMOVED_FROM_STAGE,this.onRemovedFromStage);
      }

      private function onAddedToStage(event:Event) : void
      {
         FrameProfiler.reset();
         FrameProfiler.enabled = true;
         this.lastSerial_ = -1;
         this.headerKey_.text = "profiling...";
         this.headerKey_.useTextDimensions();
         this.headerVal_.text = "";
         for(var g:int = 0; g < GROUP_COUNT; g++)
         {
            this.heads_[g].visible = false;
            this.bodies_[g].visible = false;
         }
         this.atlas_.visible = false;
         stage.addEventListener(Event.ENTER_FRAME,this.onEnterFrame);
      }

      private function onRemovedFromStage(event:Event) : void
      {
         stage.removeEventListener(Event.ENTER_FRAME,this.onEnterFrame);
         FrameProfiler.enabled = false;
      }

      private function makeToggle(index:int) : Function
      {
         return function(event:MouseEvent) : void
         {
            toggleGroup(index);
         };
      }

      private function toggleGroup(index:int) : void
      {
         this.expanded_[index] = !this.expanded_[index];
         if(this.lastSerial_ >= 0)
         {
            this.render();
         }
      }

      private function onEnterFrame(event:Event) : void
      {
         if(FrameProfiler.reportSerial == this.lastSerial_)
         {
            return;
         }
         this.lastSerial_ = FrameProfiler.reportSerial;
         this.render();
      }

      private function render() : void
      {
         this.headerKey_.text = Parameters.GPURenderFrame ? "gpu" : "software";
         this.headerVal_.text = "  " + FrameProfiler.reportedFrames + " fps";
         layoutRow(0,this.headerKey_,this.headerVal_);

         var renderSum:Number = sumSections(RENDER_TOP_SECTIONS);
         var scriptVal:Number = Math.max(0,FrameProfiler.avgScript - renderSum);
         var frameVal:Number = FrameProfiler.avgFrame;
         var renderVal:Number = Math.max(0,frameVal - scriptVal);

         setHead(GROUP_FRAME,"frame","  " + fmt(frameVal));
         setHead(GROUP_SCRIPT,"script","  " + fmt(scriptVal));
         setScriptBody(scriptVal);
         setHead(GROUP_RENDER,"render","  " + fmt(renderVal));
         setRenderBody(renderSum,Math.max(0,renderVal - renderSum));
         var sceneTotal:Number = FrameProfiler.avgObjects + FrameProfiler.avgTiles;
         setHead(GROUP_SCENE,"scene","  " + int(sceneTotal) + " items");
         setSceneBody();

         var showAtlas:Boolean = Parameters.GPURenderFrame && FrameProfiler.atlasInfo.length > 0;
         if(showAtlas)
         {
            this.atlas_.text = FrameProfiler.atlasInfo;
            this.atlas_.useTextDimensions();
         }

         var y:Number = 0;
         this.headerKey_.y = 0;
         this.headerVal_.y = 0;
         y += this.headerKey_.height;
         y = placeHead(GROUP_FRAME,0,y);
         this.bodies_[GROUP_FRAME].visible = false;
         if(this.expanded_[GROUP_FRAME])
         {
            y = placeGroup(GROUP_RENDER,BODY_INDENT,y);
            y = placeGroup(GROUP_SCRIPT,BODY_INDENT,y);
         }
         else
         {
            hideGroup(GROUP_SCRIPT);
            hideGroup(GROUP_RENDER);
         }
         y = placeGroup(GROUP_SCENE,0,y);
         this.atlas_.visible = showAtlas;
         if(showAtlas)
         {
            this.atlas_.x = 0;
            this.atlas_.y = y;
         }
      }

      private function placeHead(g:int, indent:Number, y:Number) : Number
      {
         this.heads_[g].visible = true;
         this.heads_[g].x = indent;
         this.heads_[g].y = y;
         return y + this.heads_[g].height;
      }

      private function placeGroup(g:int, indent:Number, y:Number) : Number
      {
         y = placeHead(g,indent,y);
         this.bodies_[g].visible = this.expanded_[g];
         if(this.expanded_[g])
         {
            this.bodies_[g].x = indent + BODY_INDENT;
            this.bodies_[g].y = y;
            y += this.bodies_[g].height;
         }
         return y;
      }

      private function hideGroup(g:int) : void
      {
         this.heads_[g].visible = false;
         this.bodies_[g].visible = false;
      }

      private function setHead(g:int, label:String, val:String) : void
      {
         this.headLabels_[g].text = label;
         this.headVals_[g].text = val;
         layoutRow(0,this.headLabels_[g],this.headVals_[g]);
         var arrow:Sprite = this.headArrows_[g];
         drawArrow(arrow,this.expanded_[g]);
         arrow.x = this.headVals_[g].x + this.headVals_[g].width + ARROW_GAP;
         arrow.y = Math.max(0,(this.headLabels_[g].height - ARROW_SIZE) / 2);
      }

      private function setBody(g:int, keys:String, vals:String) : void
      {
         var keyLines:Array = keys.split("\n");
         var valLines:Array = vals.split("\n");
         var n:int = Math.min(keyLines.length,MAX_BODY_ROWS);
         var base:int = g * MAX_BODY_ROWS;
         var maxKeyW:Number = 0;
         for(var r:int = 0; r < n; r++)
         {
            var keyField:SimpleText = this.bodyRowKeys_[base + r];
            keyField.text = r < keyLines.length ? keyLines[r] : "";
            keyField.useTextDimensions();
            if(keyField.width > maxKeyW)
            {
               maxKeyW = keyField.width;
            }
            var valField:SimpleText = this.bodyRowVals_[base + r];
            valField.text = r < valLines.length ? valLines[r] : "";
            valField.useTextDimensions();
         }
         var rowH:Number = 0;
         for(r = 0; r < n; r++)
         {
            rowH = Math.max(rowH,this.bodyRowKeys_[base + r].height,this.bodyRowVals_[base + r].height);
         }
         var step:Number = Math.max(1,rowH - ROW_TIGHTEN);
         var body:Sprite = this.bodies_[g];
         for(r = 0; r < MAX_BODY_ROWS; r++)
         {
            var row:Sprite = this.bodyRows_[base + r];
            if(r < n)
            {
               if(row.parent == null)
               {
                  body.addChild(row);
               }
               row.x = 0;
               row.y = r * step;
               var shownKey:SimpleText = this.bodyRowKeys_[base + r];
               shownKey.x = 0;
               shownKey.y = (step - shownKey.height) / 2;
               var shownVal:SimpleText = this.bodyRowVals_[base + r];
               shownVal.x = maxKeyW + COL_GAP;
               shownVal.y = (step - shownVal.height) / 2;
            }
            else if(row.parent != null)
            {
               row.parent.removeChild(row);
            }
         }
      }

      private function setScriptBody(scriptVal:Number) : void
      {
         var update:Number = FrameProfiler.avgSection[FrameProfiler.UPDATE];
         var hud:Number = FrameProfiler.avgSection[FrameProfiler.HUD];
         var other:Number = Math.max(0,scriptVal - update - hud);
         setRowsBody(GROUP_SCRIPT,[{k:"update",v:update,t:fmt(update)},{k:"hud",v:hud,t:fmt(hud)},{k:"other",v:other,t:fmt(other)}],"","");
      }

      private function setRenderBody(renderSum:Number, idle:Number) : void
      {
         var rows:Array = [];
         for(var k:int = 0; k < RENDER_TOP_SECTIONS.length; k++)
         {
            var val:Number = FrameProfiler.avgSection[RENDER_TOP_SECTIONS[k]];
            rows.push({k:FrameProfiler.SECTION_NAMES[RENDER_TOP_SECTIONS[k]],v:val,t:fmt(val)});
         }
         rows.push({k:"idle",v:idle,t:fmt(idle)});
         var tailKeys:String = "";
         var tailVals:String = "";
         if(Parameters.GPURenderFrame)
         {
            for(k = 0; k < RENDER_SUB_SECTIONS.length; k++)
            {
               tailKeys += FrameProfiler.SECTION_NAMES[RENDER_SUB_SECTIONS[k]] + "\n";
               tailVals += "(" + fmt(FrameProfiler.avgSection[RENDER_SUB_SECTIONS[k]]) + ")\n";
            }
         }
         setRowsBody(GROUP_RENDER,rows,tailKeys,tailVals);
      }

      private function setSceneBody() : void
      {
         var objs:Number = FrameProfiler.avgObjects;
         var tiles:Number = FrameProfiler.avgTiles;
         var draws:Number = FrameProfiler.avgDrawCalls;
         setRowsBody(GROUP_SCENE,[{k:"objs",v:objs,t:int(objs).toString()},{k:"tiles",v:tiles,t:int(tiles).toString()},
            {k:"draws",v:draws,t:int(draws).toString()}],"","");
      }

      private function setRowsBody(g:int, rows:Array, tailKeys:String, tailVals:String) : void
      {
         rows.sortOn("v",Array.NUMERIC | Array.DESCENDING);
         var keys:String = "";
         var vals:String = "";
         for(var i:int = 0; i < rows.length; i++)
         {
            keys += rows[i].k + "\n";
            vals += rows[i].t + "\n";
         }
         keys += tailKeys;
         vals += tailVals;
         if(keys.charAt(keys.length - 1) == "\n")
         {
            keys = keys.substring(0,keys.length - 1);
         }
         if(vals.charAt(vals.length - 1) == "\n")
         {
            vals = vals.substring(0,vals.length - 1);
         }
         setBody(g,keys,vals);
      }

      private static function makeText(bold:Boolean) : SimpleText
      {
         var text:SimpleText = new SimpleText(12,16777215,false,0,0);
         if(bold)
         {
            text.setBold(true);
         }
         text.filters = [new GlowFilter(0,1,2,2,3,1)];
         return text;
      }

      private static function makeArrow() : Sprite
      {
         var arrow:Sprite = new Sprite();
         arrow.mouseEnabled = false;
         arrow.filters = [new GlowFilter(0,1,2,2,3,1)];
         return arrow;
      }

      private static function layoutRow(startX:Number, ...fields) : void
      {
         var x:Number = startX;
         for each (var field:SimpleText in fields)
         {
            field.useTextDimensions();
            field.x = x;
            field.y = 0;
            x += field.width;
         }
      }

      private static function drawArrow(arrow:Sprite, down:Boolean) : void
      {
         arrow.graphics.clear();
         arrow.graphics.beginFill(16777215);
         if(down)
         {
            arrow.graphics.moveTo(0,1);
            arrow.graphics.lineTo(ARROW_SIZE,1);
            arrow.graphics.lineTo(ARROW_SIZE / 2,ARROW_SIZE - 1);
            arrow.graphics.lineTo(0,1);
         }
         else
         {
            arrow.graphics.moveTo(1,0);
            arrow.graphics.lineTo(1,ARROW_SIZE);
            arrow.graphics.lineTo(ARROW_SIZE - 1,ARROW_SIZE / 2);
            arrow.graphics.lineTo(1,0);
         }
         arrow.graphics.endFill();
      }

      private static function sumSections(sections:Vector.<int>) : Number
      {
         var total:Number = 0;
         for(var k:int = 0; k < sections.length; k++)
         {
            total += FrameProfiler.avgSection[sections[k]];
         }
         return total;
      }

      private static function fmt(ms:Number) : String
      {
         return (Math.round(ms * 100) / 100).toFixed(2) + " ms";
      }
   }
}
