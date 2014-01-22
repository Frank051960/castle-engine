{
  Copyright 2001-2014 Michalis Kamburelis.

  This file is part of "Castle Game Engine".

  "Castle Game Engine" is free software; see the file COPYING.txt,
  included in this distribution, for details about the copyright.

  "Castle Game Engine" is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

  ----------------------------------------------------------------------------
}

{ 2D fonts (TCastleFont, TTextureFont, TSimpleTextureFont). }
unit CastleFonts;

{$I castleconf.inc}

interface

uses Classes, CastleGLImages, CastleStringUtils, CastleColors,
  CastleVectors, CastleTextureFontData, CastleImages;

type
  { Abstract class for 2D font. }
  TCastleFont = class abstract
  private
    CalculatedRowHeight: boolean;
    FRowHeight, FRowHeightBase: Integer;
  protected
    { Calculate suitable values for RowHeight and RowHeightBase.
      The default implementation in TCastleFont looks at
      @code(TextHeight('Wy')) and @code(TextHeight('y')). }
    procedure UpdateRowHeight(out ARowHeight, ARowHeightBase: Integer); virtual;
  public
    { Draw text at the current WindowPos, and move
      the WindowPos at the end. This way you can immediately
      call another PrintAndMove again, to add something at the end.

      It is not adviced to use it, as using the global WindowPos leads
      sooner or later to messy in code, that has to deal with global state.
      If you need to know how to move after printing text, use TextMove.

      May require 1 free slot on the attributes stack.
      May only be called when current matrix is modelview.
      Doesn't modify any OpenGL state or matrix, except it moves raster position. }
    procedure PrintAndMove(const s: string); deprecated;

    { Draw text at the given position with given color.
      If the last Color component is not 1, the text is rendered
      with blending.

      Overloaded version without X, Y uses WindowPos (but doesn't modify
      it, in contrast to PrintAndMove).
      Overloaded version without Color uses CurrentColor,
      last color set by glColorv.
      It is not adviced to use overloaded versions without X, Y or Color
      --- using global state leads to messy code.
      You should upgrade your code to use the version that gets X,Y,Color
      explicitly.

      May require 1 free slot on the attributes stack.
      May only be called when current matrix is modelview.
      Doesn't modify any OpenGL state or matrix, except it moves raster position. }
    procedure Print(const X, Y: Integer; const Color: TCastleColor;
      const S: string); overload; virtual; abstract;
    procedure Print(const Pos: TVector2Integer; const Color: TCastleColor;
      const S: string); overload;
    procedure Print(const X, Y: Integer; const S: string); overload; deprecated;
    procedure Print(const s: string); overload; deprecated;

    function TextWidth(const S: string): Integer; virtual; abstract;
    function TextHeight(const S: string): Integer; virtual; abstract;
    function TextMove(const S: string): TVector2Integer; virtual; abstract;

    { The height (above the baseline) of the text.
      This doesn't take into account height of the text below the baseline
      (for example letter "y" has the tail below the baseline in most fonts). }
    function TextHeightBase(const S: string): Integer; virtual; abstract;

    { Height of a row of text in this font.
      This may be calculated as simply @code(TextHeight('Wy')) for most
      normal fonts. }
    function RowHeight: Integer;

    { Height (above the baseline) of a row of text in this font.
      Similar to TextHeightBase and TextHeight,
      note that RowHeightBase is generally smaller than RowHeight,
      because RowHeightBase doesn't care how low the letter may go below
      the baseline. }
    function RowHeightBase: Integer;

    { How low the text may go below the baseline.
      By default this returns @code(TextHeight('y')-TextHeight('a')),
      which is suitable for normal fonts. }
    function Descend: Integer; virtual;

    { Break lines (possibly break one long string into more strings)
      to fit the text with given MaxLineWidth.

      This takes into account current font information (works also
      for non-monospace fonts, of course), and converts your Unbroken
      text into Broken text, such that TextWidth of the longest Broken
      line fits within MaxLineWidth.

      Tries to break on white characters. If not possible (there's
      a long stream of non-white characters that really has to be broken),
      it will break in the middle of normal (non-white) characters.
      The only situation when we have to fail, and the resulting
      Broken text is wider than required MaxLineWidth, is when
      @italic(a single character in your font) is wider than MaxLineWidth.
      In such case, there's really no solution, and we'll just let such
      character stay.

      If you use the overloaded version where Unbroken is just a string,
      then note that already existing newlines (NL) inside Unbroken
      will be correctly preserved.

      If you use the overloaded version with separate Unbroken and
      Broken parameters, then the previous Broken contents are not modified.
      We only append to Broken new strings, coming from Unbroken text.
      The overloaded version that takes only Broken parameter
      (no Unbroken parameter) simply modifies it's Broken parameter
      (from the line FirstToBreak).

      @groupBegin }
    procedure BreakLines(const unbroken: string; broken: TStrings; maxLineWidth: integer); overload;
    procedure BreakLines(unbroken, broken: TStrings; maxLineWidth: integer); overload;
    procedure BreakLines(broken: TStrings; maxLineWidth: Integer; FirstToBreak: integer); overload;
    { @groupEnd }

    { Largest width of the line of text in given list.

      @param(Tags Indicates that strings inside SList use HTML-like
        tags, the same as interpreted by PrintStrings.
        If your SList uses these tags (for example, you plan to call later
        PrintStrings with the same SList and Tags = @true) then make
        sure you pass Tags = @true to this method.
        Otherwise, MaxTextWidth will treat tags text (like @code(<font ...>))
        like a normal text, usually making the width incorrectly large.)
    }
    function MaxTextWidth(SList: TStrings; const Tags: boolean = false): Integer;

    { Print all strings from the list.

      X0, Y0 is the bottom-left position of the whole text block
      (that is, it is the bottom-left position of the last string).
      Distance between each line is (RowHeight + BonusVerticalSpace) pixels.

      Note that BonusVerticalSpace can be < 0 (as well as > 0),
      this may be sometimes useful if you really want to squeeze
      more text into some size. Still, make sure that
      (RowHeight + BonusVerticalSpace) is > 0.

      May require 1 free slot on the attributes stack.
      May only be called when current matrix is modelview.
      Doesn't modify any OpenGL state or matrix, except it moves raster position.

      @param(Tags Enable some HTML-like tags to mark font changes inside the text.
        For now, these can only be used to surround whole lines
        (so you have to place opening tag at the beginnig of line,
        and closing tag at the end of line).
        For now, the only tag handled is @code(<font color="#rrggbb">)
        that changes line color to specified RGB.
        Also, we handle @code(<font color="#rrggbbaa">) where the last
        component is alpha (opacity), and when it's < 1 then we render using blending.
        Close with @code(</font>).

        This functionality may be enhanced in the future (feature requests
        and patches welcome). Don't expect full HTML implementation inside,
        but some small set of useful tags may be doable and comfortable to use.
        Not necessarily replicating some (old version of) HTML standard.
      )

      Overloaded and deprecated versions without
      explicit Color parameter use CurrentColor.

      @groupBegin }
    procedure PrintStrings(const X0, Y0: Integer; const Color: TCastleColor;
      const Strs: TStrings; const Tags: boolean;
      const BonusVerticalSpace: Integer); overload;
    procedure PrintStrings(const Strs: TStrings;
      const Tags: boolean; const BonusVerticalSpace: Integer;
      const X0: Integer = 0; const Y0: Integer = 0); overload; deprecated;
    procedure PrintStrings(const Strs: array of string;
      const Tags: boolean; const BonusVerticalSpace: Integer;
      const X0: Integer = 0; const Y0: Integer = 0); overload; deprecated;
    { @groupEnd }

    { Print the string, broken such that it fits within MaxLineWidth.
      The string is broken into many lines using BreakLines,
      so the original newlines insides are correctly used,
      and the length of lines fits inside MaxLineWidth.

      The strings are printed on the screen, just like by PrintStrings
      (with Tags = always false for now, since our string breaking cannot
      omit tags).
      If PositionsFirst then the X0, Y0 determine
      the position of the first (top) line, otherwise they determine
      the position of the last (bottom) line.

      BonusVerticalSpace has the same meaning as for PrintStrings:
      it adds an additional space between lines (if positive) or forces
      the lines to be more tightly squeezed (if negative). Always make
      sure that (RowHeight + BonusVerticalSpace) > 0.

      Returns the number of lines printed, that is the number of lines
      after breaking the text into lines. This may be useful e.g. to calculate
      the height of the printed text.

      May require 1 free slot on the attributes stack.
      May only be called when current matrix is modelview.
      Doesn't modify any OpenGL state or matrix.

      Overloaded and deprecated version without
      explicit Color parameter uses CurrentColor.

      @groupBegin }
    function PrintBrokenString(X0, Y0: Integer; const Color: TCastleColor;
      const S: string; const MaxLineWidth: Integer;
      const PositionsFirst: boolean;
      const BonusVerticalSpace: Integer): Integer;
    function PrintBrokenString(const S: string;
      const MaxLineWidth, X0, Y0: Integer;
      const PositionsFirst: boolean;
      const BonusVerticalSpace: Integer): Integer; deprecated;
    { @groupEnd }
  end;

  { @deprecated Deprecated name for TCastleFont. }
  TGLBitmapFontAbstract = TCastleFont deprecated;

  { 2D font using a texture initialized from a FreeType font file.

    This can load a font file, or it can use ready data in TTextureFontData.
    The latter allows to use this for fonts embedded in a Pascal source code,
    since our texturefont2pascal can convert a font ttf to a unit that defines
    ready TTextureFontData instance. }
  TTextureFont = class(TCastleFont)
  private
    FFont: TTextureFontData;
    FOwnsFont: boolean;
    Image: TGLImage;
  public
    {$ifdef HAS_FREE_TYPE}
    { Create by reading a FreeType font file, like ttf. }
    constructor Create(const URL: string;
      const ASize: Integer; const AnAntiAliased: boolean;
      const ACharacters: TSetOfChars = SimpleAsciiCharacters);
    {$endif}
    { Create from a ready TTextureFontData instance.
      Data instance becomes owned by this class if and only if OwnsData. }
    constructor Create(const Data: TTextureFontData; const OwnsData: boolean);
    destructor Destroy; override;
    procedure Print(const X, Y: Integer; const Color: TCastleColor;
      const S: string); override;
    function TextWidth(const S: string): Integer; override;
    function TextHeight(const S: string): Integer; override;
    function TextMove(const S: string): TVector2Integer; override;
    function TextHeightBase(const S: string): Integer; override;
  end;

  { @deprecated Deprecated name, use TTextureFont now. }
  TGLBitmapFont = TTextureFont deprecated;

  { 2D font using a texture to define character images
    with constant width and height.

    This class has some assumptions about how the font image looks like:
    the characters are drawn in ASCII order, starting from space, on an image.
    Derive your own descendants of TCastleFont to have more flexibility,
    see the implementation of this class --- it is quite simple.
    Or use TTextureFont that can read data from a FreeType (like ttf) font file.

    See e.g. castle_game_engine/examples/fonts/data/sonic_asalga_0.png
    how to prepare an image for use with such font.
    You can find more such fonts on the Internet, see
    e.g. http://opengameart.org/content/sonic-font and
    http://opengameart.org/content/null-terminator. }
  TSimpleTextureFont = class(TCastleFont)
  private
    Image: TGLImage;
    ImageCols, ImageRows,
      CharMargin, CharDisplayMargin, CharWidth, CharHeight: Integer;
  public
    { Load font from given image.
      @param AImage Image data, becomes owned by this class.
      @param ACharMargin There is a margin in the image between rows and cols.
      @param(ACharDisplayMargin We can display some spacing between characters.
        This is independent from CharMargin and image contents.) }
    constructor Create(AImage: TCastleImage;
      const AImageCols, AImageRows, ACharMargin, ACharDisplayMargin: Integer);
    destructor Destroy; override;
    procedure Print(const X, Y: Integer; const Color: TCastleColor;
      const S: string); override;
    function TextWidth(const S: string): Integer; override;
    function TextHeight(const S: string): Integer; override;
    function TextMove(const S: string): TVector2Integer; override;
    function TextHeightBase(const S: string): Integer; override;
  end;

implementation

uses CastleClassUtils, CastleGLUtils, SysUtils, CastleUtils, Math;

{ HandleTags ----------------------------------------------------------------- }

function HandleTags(const S: string;
  out ColorChange: boolean; out Color: TCastleColor): string;

  function ExtractColor(const S: string; P: Integer;
    out Color: TCastleColor; out Length: Integer): boolean;
  const
    HexDigits = ['0'..'9', 'a'..'f', 'A'..'F'];
  begin
    Result := SCharIs(S, P    , HexDigits) and
              SCharIs(S, P + 1, HexDigits) and
              SCharIs(S, P + 2, HexDigits) and
              SCharIs(S, P + 3, HexDigits) and
              SCharIs(S, P + 4, HexDigits) and
              SCharIs(S, P + 5, HexDigits);
    Length := 6;
    if Result then
    begin
      Color[0] := StrHexToInt(Copy(S, P    , 2)) / 255;
      Color[1] := StrHexToInt(Copy(S, P + 2, 2)) / 255;
      Color[2] := StrHexToInt(Copy(S, P + 4, 2)) / 255;
      if SCharIs(S, P + 6, HexDigits) and
         SCharIs(S, P + 7, HexDigits) then
      begin
        Length += 2;
        Color[3] := StrHexToInt(Copy(S, P + 6, 2)) / 255;
      end else
        Color[3] := 1.0;
    end;
  end;

  { Is SubText present inside Text on position P.
    Secure for all lengths and values of position (that is, will answer
    false if P is <= 0 or P is too large and some part of SubText would
    be outside S). }
  function SubStringMatch(const SubText, Text: string; P: Integer): boolean;
  var
    I: Integer;
  begin
    Result := (P >= 1) and
              (P <= { signed } Integer(Length(Text)) - Length(SubText) + 1);
    if Result then
      for I := 1 to Length(SubText) do
      begin
        if SubText[I] <> Text[P] then Exit(false);
        Inc(P);
      end;
  end;

const
  SFontColorBegin1 = '<font color="#';
  SFontColorBegin2 = '">';
  SFontEnd = '</font>';
var
  ColorLength: Integer;
begin
  ColorChange :=
    { first check something most likely to fail, for speed }
    SCharIs(S, 1, '<') and
    SubStringMatch(SFontColorBegin1, S, 1) and
    ExtractColor(S, Length(SFontColorBegin1) + 1, Color, ColorLength) and
    SubStringMatch(SFontColorBegin2, S, Length(SFontColorBegin1) + ColorLength + 1) and
    SubStringMatch(SFontEnd, S, Length(S) - Length(SFontEnd) + 1);

  if ColorChange then
  begin
    Result := CopyPos(S,
      Length(SFontColorBegin1) + Length(SFontColorBegin2) + ColorLength + 1,
      Length(S) - Length(SFontEnd));
  end else
    Result := S;
end;

{ TCastleFont ------------------------------------------------------}

procedure TCastleFont.Print(const Pos: TVector2Integer;
  const Color: TCastleColor; const S: string);
begin
  Print(Pos[0], Pos[1], Color, S);
end;

procedure TCastleFont.Print(const s: string);
begin
  Print(WindowPos[0], WindowPos[1], CurrentColor, S);
end;

procedure TCastleFont.PrintAndMove(const S: string);
begin
  { Deprecated method uses other deprecated method here, don't warn }
  {$warnings off}
  Print(S);
  {$warnings on}
  WindowPos := WindowPos + TextMove(S);
end;

procedure TCastleFont.Print(const X, Y: Integer; const S: string);
begin
  Print(X, Y, CurrentColor, S);
end;

function TCastleFont.Descend: Integer;
begin
  result := TextHeight('y')-TextHeight('a');
end;

procedure TCastleFont.BreakLines(const unbroken: string;
  broken: TStrings; maxLineWidth: integer);
var
  unbrokenlist: TStringList;
begin
  unbrokenlist := TStringList.Create;
  try
    Strings_SetText(unbrokenlist, unbroken);
    BreakLines(unbrokenlist, broken, maxLineWidth);
  finally unbrokenlist.Free end;
end;

procedure TCastleFont.BreakLines(unbroken, broken: TStrings;
  maxLineWidth: integer);
var
  i, FirstToBreak: Integer;
begin
  FirstToBreak := broken.count;
  for I := 0 to unbroken.count-1 do broken.Append(unbroken[i]);
  BreakLines(broken, maxLineWidth, FirstToBreak);
end;

procedure TCastleFont.BreakLines(broken: TStrings;
  maxLineWidth: Integer; FirstToBreak: integer);
var
  i, j: Integer;
  linew: Integer;
  p: Integer;
  break1, break2: string;
begin
  { ponizej lamiemy stringi unbroken.
    Lamanie to nie jest takie proste bo my nie mamy czegos takiego jak
    MaxCol - ilosc znakow w linii, bo kazdy znak moze miec inna szerokosc -
    font nie musi byc monospaced ! Gdyby byl - no coz, to robota bylaby prosta :
     broken.text := WrapText(broken.text, maxLineWidth div font.TextWidth('w'));
     (no, zakladajac ze FirstToBreak = 0)
    i juz. A tak - musimy po kolei badac kazdy string szukajac w nim literki
    ktora sprawia ze nie miesci sie w maxLineWidth i wtedy obcinac.
  }

  i := FirstToBreak;
  { instead of "for" use "while" because broken.count will be changing }
  while i < broken.count do
  begin
    { zobacz czy nie trzeba zlamac linii nr i.
      Linii '' z pewnoscia nie trzeba lamac. }
    if broken[i] <> '' then
    begin
      { ponizsze dwie linijki implikuja ze do zlamanej linii ZAWSZE trafia
        pierwszy znak z linii niezlamanej, NAWET jesli ten pierwszy znak
        jest szerszy niz maxLineWidth. No bo jezeli ten znak jest szerszy
        od maxLineWidth to przeciez nie moglby trafic do ZADNEJ linii,
        prawda ? Jedyna alternatywa byloby rzucenie w takim wypadku
        wyjatku z komunikatem ze "maxLineWidth" jest za male zeby w pelni
        poprawnie polamac string. }
      linew := TextWidth(broken[i][1]);
      j := 2;
      while (j <= Length(broken[i])) and
            (linew + TextWidth(broken[i][j]) <= maxLineWidth) do
      begin
        linew := linew + TextWidth(broken[i][j]);
        Inc(j);
      end;
      if j <= Length(broken[i]) then
      begin
        { oho ! ta linie trzeba zlamac przed znakiem j, bo linia jest za dluga kiedy
          ma j znakow. Efekt breaka bedzie tez taki ze broken.count sie zwiekszy wiec
          w nastepnym obrocie petli bedziemy lamali dalsza czesc tej linii - i o to
          chodzi. }
        p := BackCharsPos(WhiteSpaces, Copy(broken[i], 1,j));
        if p > 0 then
        begin
          break1 := Copy(broken[i], 1,p-1);
          break2 := SEnding(broken[i], p+1) { break at pos p, delete p-th char }
        end else
        begin
          break1 := Copy(broken[i], 1,j-1);
          break2 := SEnding(broken[i], j);  { break at pos j-1 }
        end;
        broken[i] := break1;
        broken.Insert(i+1, break2);
      end;
    end;

    Inc(i);
  end;
end;

function TCastleFont.MaxTextWidth(SList: TStrings;
  const Tags: boolean): Integer;
var
  I, LineW: Integer;
  DummyColorChange: boolean;
  DummyColor: TCastleColor;
  S: string;
begin
  result := 0;
  for I := 0 to slist.Count-1 do
  begin
    S := SList[i];
    if Tags then
      S := HandleTags(S, DummyColorChange, DummyColor);
    LineW := TextWidth(S);
    if LineW > result then result := LineW;
  end;
end;

procedure TCastleFont.PrintStrings(const X0, Y0: Integer;
  const Color: TCastleColor; const Strs: TStrings;
  const Tags: boolean; const BonusVerticalSpace: Integer);
var
  Line: Integer;

  function YPos: Integer;
  begin
    Result := (Strs.Count - 1 - Line) * (RowHeight + BonusVerticalSpace) + Y0;
  end;

var
  S: string;
  ColorChange: boolean;
  ColorChanged: TCastleColor;
begin
  for Line := 0 to Strs.Count - 1 do
  begin
    S := Strs[Line];
    if Tags then
    begin
      S := HandleTags(S, ColorChange, ColorChanged);
      if ColorChange then
        Print(X0, YPos, ColorChanged, S) else
        Print(X0, YPos, Color, S);
    end else
      Print(X0, YPos, Color, S);
  end;
end;

procedure TCastleFont.PrintStrings(const Strs: TStrings;
  const Tags: boolean; const BonusVerticalSpace: Integer;
  const X0: Integer; const Y0: Integer);
begin
  PrintStrings(X0, Y0, CurrentColor, Strs, Tags, BonusVerticalSpace);
end;

procedure TCastleFont.PrintStrings(const Strs: array of string;
  const Tags: boolean; const BonusVerticalSpace: Integer;
  const X0, Y0: Integer);
var
  SList: TStringList;
begin
  SList := TStringList.Create;
  try
    AddStrArrayToStrings(Strs, SList);
    PrintStrings(X0, Y0, CurrentColor, SList, Tags, BonusVerticalSpace);
  finally SList.Free end;
end;

function TCastleFont.PrintBrokenString(
  X0, Y0: Integer; const Color: TCastleColor; const s: string;
  const MaxLineWidth: Integer;
  const PositionsFirst: boolean;
  const BonusVerticalSpace: Integer): Integer;
var
  broken: TStringList;
begin
  broken := TStringList.Create;
  try
    BreakLines(s, broken, MaxLineWidth);
    if PositionsFirst then
      Y0 -= (broken.Count-1)*(RowHeight + BonusVerticalSpace);
    PrintStrings(X0, Y0, Color, broken, false, BonusVerticalSpace);
    result := broken.Count;
  finally broken.Free end;
end;

function TCastleFont.PrintBrokenString(const S: string;
  const MaxLineWidth, X0, Y0: Integer;
  const PositionsFirst: boolean;
  const BonusVerticalSpace: Integer): Integer; deprecated;
begin
  Result := PrintBrokenString(X0, Y0, CurrentColor, S, maxLineWidth,
    PositionsFirst, BonusVerticalSpace);
end;

procedure TCastleFont.UpdateRowHeight(out ARowHeight, ARowHeightBase: Integer);
begin
  ARowHeight := TextHeight('Wy') + 2;
  { RowHeight zwiekszylem o +2 zeby byl odstep miedzy liniami.
    TODO: this +2 is actually a bad idea, but can't remove now without careful testing. }
  { For RowHeightBase, I do not use +2. }
  ARowHeightBase := TextHeightBase('W');
end;

function TCastleFont.RowHeight: Integer;
begin
  if not CalculatedRowHeight then
  begin
    UpdateRowHeight(FRowHeight, FRowHeightBase);
    CalculatedRowHeight := true;
  end;
  Result := FRowHeight;
end;

function TCastleFont.RowHeightBase: Integer;
begin
  if not CalculatedRowHeight then
  begin
    UpdateRowHeight(FRowHeight, FRowHeightBase);
    CalculatedRowHeight := true;
  end;
  Result := FRowHeightBase;
end;

{ TTextureFont --------------------------------------------------------------- }

{$ifdef HAS_FREE_TYPE}
constructor TTextureFont.Create(const URL: string;
  const ASize: Integer; const AnAntiAliased: boolean;
  const ACharacters: TSetOfChars);
begin
  Create(TTextureFontData.Create(URL, ASize, AnAntiAliased, ACharacters), true);
end;
{$endif}

constructor TTextureFont.Create(const Data: TTextureFontData; const OwnsData: boolean);
begin
  inherited Create;
  FOwnsFont := OwnsData;
  FFont := Data;
  Image := TGLImage.Create(FFont.Image, false);
end;

destructor TTextureFont.Destroy;
begin
  FreeAndNil(Image);
  if FOwnsFont then
    FreeAndNil(FFont) else
    FFont := nil;
  inherited;
end;

procedure TTextureFont.Print(const X, Y: Integer; const Color: TCastleColor;
  const S: string);
var
  C: char;
  ScreenX, ScreenY: Integer;
  G: TTextureFontData.TGlyph;
begin
  Image.Color := Color;
  ScreenX := X;
  ScreenY := Y;
  for C in S do
  begin
    G := FFont.Glyph(C);
    if G <> nil then
    begin
      if (G.Width <> 0) and (G.Height <> 0) then
        Image.Draw(ScreenX - G.X, ScreenY - G.Y, G.Width, G.Height,
          G.ImageX, G.ImageY, G.Width, G.Height);
      ScreenX += G.AdvanceX;
      ScreenY += G.AdvanceY;
    end;
  end;
end;

function TTextureFont.TextWidth(const S: string): Integer;
var
  C: char;
  G: TTextureFontData.TGlyph;
begin
  Result := 0;
  for C in S do
  begin
    G := FFont.Glyph(C);
    if G <> nil then
      Result += G.AdvanceX;
  end;
end;

function TTextureFont.TextHeight(const S: string): Integer;
var
  C: char;
  MinY, MaxY, YOrigin: Integer;
  G: TTextureFontData.TGlyph;
begin
  MinY := 0;
  MaxY := 0;
  for C in S do
  begin
    G := FFont.Glyph(C);
    if G <> nil then
    begin
      YOrigin := G.Y;
      MinTo1st(MinY, -YOrigin);
      MaxTo1st(MaxY, G.Height - YOrigin);
    end;
  end;
  Result := MaxY - MinY;
end;

function TTextureFont.TextHeightBase(const S: string): Integer;
var
  C: char;
  G: TTextureFontData.TGlyph;
begin
  Result := 0;
  { This is just like TextHeight implementation, except we only
    calculate (as Result) the MaxY value (assuming that MinY is zero). }
  for C in S do
  begin
    G := FFont.Glyph(C);
    if G <> nil then
      MaxTo1st(Result, G.Height - G.Y);
  end;
end;

function TTextureFont.TextMove(const S: string): TVector2Integer;
var
  C: char;
  G: TTextureFontData.TGlyph;
begin
  Result := ZeroVector2Integer;
  for C in S do
  begin
    G := FFont.Glyph(C);
    if G <> nil then
    begin
      Result[0] += G.AdvanceX;
      Result[1] += G.AdvanceY;
    end;
  end;
end;

{ TSimpleTextureFont --------------------------------------------------------- }

constructor TSimpleTextureFont.Create(AImage: TCastleImage;
  const AImageCols, AImageRows, ACharMargin, ACharDisplayMargin: Integer);
begin
  inherited Create;
  Image := TGLImage.Create(AImage, false);
  FreeAndNil(AImage); // not needed anymore

  ImageCols := AImageCols;
  ImageRows := AImageRows;
  CharMargin := ACharMargin;
  CharWidth := Image.Width div ImageCols - CharMargin;
  CharHeight := Image.Height div ImageRows - CharMargin;
  CharDisplayMargin := ACharDisplayMargin;
end;

destructor TSimpleTextureFont.Destroy;
begin
  FreeAndNil(Image);
  inherited;
end;

procedure TSimpleTextureFont.Print(const X, Y: Integer; const Color: TCastleColor;
  const S: string);
var
  ImageX, ImageY: Single;
  I, CharIndex, ScreenX, ScreenY: Integer;
begin
  Image.Color := Color;
  for I := 1 to Length(S) do
  begin
    CharIndex := Ord(S[I]) - Ord(' ');
    ImageX := CharIndex mod ImageCols;
    ImageY := CharIndex div ImageCols;
    if ImageY < ImageRows then
    begin
      ImageX := ImageX * (CharWidth + CharMargin);
      ImageY := Image.Height - (ImageY + 1) * (CharHeight + CharMargin);
      ScreenX := CharDisplayMargin div 2 + X + (I - 1) * (CharWidth + CharDisplayMargin);
      ScreenY := CharDisplayMargin div 2 + Y;
      Image.Draw(ScreenX, ScreenY, CharWidth, CharHeight,
        ImageX, ImageY, CharWidth, CharHeight);
    end;
  end;
end;

function TSimpleTextureFont.TextWidth(const S: string): Integer;
begin
  Result := Length(S) * (CharWidth + CharDisplayMargin);
end;

function TSimpleTextureFont.TextHeight(const S: string): Integer;
begin
  Result := CharHeight + CharDisplayMargin;
end;

function TSimpleTextureFont.TextHeightBase(const S: string): Integer;
begin
  Result := CharHeight + CharDisplayMargin;
end;

function TSimpleTextureFont.TextMove(const S: string): TVector2Integer;
begin
  Result := Vector2Integer(TextWidth(S), TextHeight(S));
end;

end.

end.