package com.company.assembleegameclient.screens
{
   import com.company.assembleegameclient.ui.ClickableText;
   import com.company.assembleegameclient.ui.Scrollbar;
   import com.company.assembleegameclient.ui.layout.LayoutHelper;
   import com.company.assembleegameclient.ui.layout.MenuBackground;
   import com.company.assembleegameclient.ui.layout.MenuFrame;
   import com.company.assembleegameclient.ui.layout.ScaledScreen;
   import com.company.ui.SimpleText;
import com.hurlant.util.asn1.parser.nulll;

import flash.display.DisplayObject;
   import flash.display.Graphics;
   import flash.display.Shape;
   import flash.events.Event;
   import flash.events.MouseEvent;
   import flash.filters.DropShadowFilter;
   import flash.geom.Rectangle;
import flash.text.TextFormatAlign;

import kabam.rotmg.core.model.PlayerModel;
   import kabam.rotmg.game.view.CreditDisplay;
   import org.osflash.signals.Signal;
   import org.osflash.signals.natives.NativeMappedSignal;

   public class CharacterSelectionAndNewsScreen extends ScaledScreen
   {
       
      
      private const SCROLLBAR_REQUIREMENT_HEIGHT:Number = 400;
      
      private const DROP_SHADOW:DropShadowFilter = new DropShadowFilter(0,0,0,1,8,8);
      
      private var model:PlayerModel;
      
      private var isInitialized:Boolean;
      
      private var nameText:SimpleText;
      
      private var creditDisplay:CreditDisplay;
      
      private var charactersText:SimpleText;
      
      private var newsText:SimpleText;

      private var newsList:NewsList;
      
      private var characterList:CharacterList;
      
      private var characterListHeight:Number;
      
      private var playButton:TitleMenuOption;
      
      private var backButton:TitleMenuOption;
      
      private var classesButton:TitleMenuOption;
      
      private var lines:Shape;

      private var dividerLine:Shape;

      private var scrollBar:Scrollbar;
      
      public var close:Signal;
      
      public var showClasses:Signal;
      
      public var newCharacter:Signal;
      
      public var playGame:Signal;
      
      public function CharacterSelectionAndNewsScreen()
      {
         this.playButton = new TitleMenuOption("play",36,true);
         this.backButton = new TitleMenuOption("back",22,false);
         this.classesButton = new TitleMenuOption("classes",22,false);
         this.newCharacter = new Signal();
         this.playGame = new Signal();
         super();
         setBackground(new MenuBackground());
         addFrame(new MenuFrame());
         this.chrome.addChild(new AccountScreen());
         this.dividerLine = new Shape();
         this.chrome.addChild(this.dividerLine);
         this.close = new NativeMappedSignal(this.backButton,MouseEvent.CLICK);
         this.showClasses = new NativeMappedSignal(this.classesButton,MouseEvent.CLICK);
      }
      
      public function initialize(model:PlayerModel) : void
      {
         if(this.isInitialized)
         {
            return;
         }
         this.isInitialized = true;
         this.model = model;
         this.createDisplayAssets(model);
      }
      
      private function createDisplayAssets(model:PlayerModel) : void
      {
         this.createNameText();
         this.createCreditDisplay();
         this.createCharactersText();
         this.createNewsText();
         this.createNewsList();
         this.createBoundaryLines();
         this.createCharacterList();

         this.createButtons();
         this.positionButtons();

         if (this.characterListHeight > this.SCROLLBAR_REQUIREMENT_HEIGHT) {
            this.createScrollbar();
         }
      }
      
      private function createButtons() : void
      {
         this.content.addChild(this.playButton);
         this.content.addChild(this.classesButton);
         this.content.addChild(this.backButton);
         this.playButton.addEventListener(MouseEvent.CLICK,this.onPlayClick);
      }
      
      private function positionButtons() : void
      {
         this.playButton.x = (this.getReferenceRectangle().width - this.playButton.width) / 2;
         this.playButton.y = 520;
         this.backButton.x = (this.getReferenceRectangle().width - this.backButton.width) / 2 - 94;
         this.backButton.y = 532;
         this.classesButton.x = (this.getReferenceRectangle().width - this.classesButton.width) / 2 + 96;
         this.classesButton.y = 532;
      }
      
      private function createScrollbar() : void
      {
         this.scrollBar = new Scrollbar(16,399);
         this.scrollBar.x = 375;
         this.scrollBar.y = 113;
         this.scrollBar.setIndicatorSize(399,this.characterList.height);
         this.scrollBar.addEventListener(Event.CHANGE,this.onScrollBarChange);
         this.content.addChild(this.scrollBar);
      }
      
      private function createCharacterList() : void
      {
         this.characterList = new CharacterList(this.model);
         this.characterList.x = 10;
         this.characterList.y = 112;
         this.characterListHeight = this.characterList.height;
         this.content.addChild(this.characterList);
      }

      private function createNewsList() : void{
         this.newsList = new NewsList(this.model);
         this.newsList.x = 400;
         this.newsList.y = 112;
         this.content.addChild(this.newsList);
      }
      
      private function createNewsText() : void
      {
         this.newsText = new SimpleText(18,11776947,false,0,0);
         this.newsText.setBold(true);
         this.newsText.text = "News";
         this.newsText.updateMetrics();
         this.newsText.filters = [this.DROP_SHADOW];
         this.newsText.setAlignment(TextFormatAlign.LEFT);
         this.newsText.x = 410;
         this.newsText.y = 79;
         this.content.addChild(this.newsText);
      }
      
      private function createCharactersText() : void
      {
         this.charactersText = new SimpleText(18,11776947,false,0,0);
         this.charactersText.setBold(true);
         this.charactersText.text = "Characters";
         this.charactersText.updateMetrics();
         this.charactersText.filters = [this.DROP_SHADOW];
         this.charactersText.setAlignment(TextFormatAlign.LEFT);
         this.charactersText.x = 10;
         this.charactersText.y = 79;
         this.content.addChild(this.charactersText);
      }
      
      private function createCreditDisplay() : void
      {
         this.creditDisplay = new CreditDisplay();
         this.creditDisplay.draw(this.model.getCredits(),this.model.getFame());
         this.chrome.addChild(this.creditDisplay);
         this.layout();
      }
      
      private function createNameText() : void
      {
         this.nameText = new SimpleText(22,11776947,false,0,0);
         this.nameText.setBold(true);
         this.nameText.text = this.model.getName() || "Undefined";
         this.nameText.updateMetrics();
         this.nameText.filters = [this.DROP_SHADOW];
         this.nameText.y = 24;
         this.nameText.x = (this.getReferenceRectangle().width - this.nameText.width) / 2;
         this.content.addChild(this.nameText);
      }

      private function getReferenceRectangle() : Rectangle
      {
         return new Rectangle(0,0,LayoutHelper.DESIGN_WIDTH,LayoutHelper.DESIGN_HEIGHT);
      }
      
      private function createBoundaryLines() : void
      {
         this.lines = new Shape();
         this.lines.graphics.clear();
         this.lines.graphics.lineStyle(2,5526612);
         this.lines.graphics.moveTo(400,107);
         this.lines.graphics.lineTo(400,526);
         this.lines.graphics.lineStyle();
         this.content.addChild(this.lines);
         this.layout();
      }

      override protected function layoutChrome(stageWidth:Number, stageHeight:Number, scale:Number) : void
      {
         if (this.creditDisplay != null)
         {
            this.creditDisplay.scaleX = scale;
            this.creditDisplay.scaleY = scale;
            this.creditDisplay.x = stageWidth;
            this.creditDisplay.y = 20 * scale;
         }
         var g:Graphics = this.dividerLine.graphics;
         g.clear();
         g.lineStyle(2 * scale,5526612);
         g.moveTo(0,105 * scale);
         g.lineTo(stageWidth,105 * scale);
         g.lineStyle();
      }
      
      private function onScrollBarChange(event:Event) : void
      {
         this.characterList.setPos(-this.scrollBar.pos() * (this.characterListHeight - 400));
      }
      
      private function removeIfAble(object:DisplayObject) : void
      {
         if(object && contains(object))
         {
            removeChild(object);
         }
      }
      
      private function onPlayClick(event:Event) : void
      {
         if(this.model.getCharacterCount() == 0)
         {
            this.newCharacter.dispatch();
         }
         else
         {
            this.playGame.dispatch();
         }
      }
      
      public function setName(name:String) : void
      {
         this.nameText.text = name;
         this.nameText.updateMetrics();
         this.nameText.x = (this.getReferenceRectangle().width - this.nameText.width) * 0.5;
      }
   }
}
