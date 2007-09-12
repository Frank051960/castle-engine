{
  Copyright 2002-2006 Michalis Kamburelis.

  This file is part of "Kambi's 3dmodels Pascal units".

  "Kambi's 3dmodels Pascal units" is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation; either version 2 of the License, or
  (at your option) any later version.

  "Kambi's 3dmodels Pascal units" is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with "Kambi's 3dmodels Pascal units"; if not, write to the Free Software
  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
}

{ @abstract(VRML fields --- @link(TVRMLField) class and descendants.) }

unit VRMLFields;

interface

uses VectorMath, Classes, SysUtils, VRMLLexer, KambiUtils, KambiClassUtils,
  Images, KambiStringUtils;

{$define read_interface}

const
  { IndentIncrement is string or char. It's used by SaveToStream }
  IndentIncrement = CharTab;

type

{ fields base classes ------------------------------------------------------ }

  { Base class for all VRML fields.

    Common notes for all descendants: most of them expose field or property
    "Value", this is (surprise, surprise!) the value of the field.
    Many of them also expose DefaultValue and DefaultValueExists
    fields/properties, these should be the default VRML value for this field.
    You can even change DefaultValue after the object is created.

    Most of descendants include constructor that initializes
    both DefaultValue and Value to the same thing, as this is what
    you usually want.

    Some notes about @link(Assign) semantics here:
    @orderedList(
      @item(There are some exceptions, but usually
        assignment is possible only when source and destination field classes
        are equal.)
      @item(Assignment tries to copy everything: name, default value,
        IsClause*, Exposed, and of course current value.))
  }
  TVRMLField = class(TPersistent)
  private
    FExposed: boolean;
    FIsClause: boolean;
    FIsClauseName: string;
  protected
    FName: string;

    { kazda klasa musi to pokryc; SaveToStream zapisuje
      Indent, Name, ' ', potem wywoluje SaveToStreamValue, potem zapisuje nl.

      Note that SaveToStream in this class
      already takes care of IsClause. If IsClause, it will do
      everything, and not call SaveToStreamValue. So when overriding
      SaveToStreamValue, you can safely assume that IsClause is @false. }
    procedure SaveToStreamValue(Stream: TStream;
      const Indent: string;
      NodeNameBinding: TStringList); virtual; abstract;

    { Call this inside overriden Assign methods.
      I don't want to place this inside TVRMLField.Assign, since I want
      "inherited" in Assign methods to cause exception. }
    procedure VRMLFieldAssignCommon(Source: TVRMLField);
  public
    { spoza tego modulu nigdy nie tworz obiektow tej klasy z Name = '',
      tzn. zawsze Name musi byc zdefiniowane.
      (w tym module mozemy gdzieniegdzie uzywac wewnetrznie takich obiektow,
      np. pozwolilo to nam bardzo wygodnie zapisac TVRMLSimpleMultField.Parse.) }
    property Name: string read fName;

    { Normal constrctor.

      Implementors notes: when implementing constructors in descendants,
      remember that Create in this class actually just calls CreateUndefined,
      and CreateUndefined is virtual. So when calling @code(inherited Create),
      be aware that actually you may be calling your own overriden
      CreateUndefined.

      In fact, in descendants you should focus on moving all the work to
      CreateUndefined constructor.
      The Create constructor should be just a comfortable extension of
      CreateUndefined, that does the same and addiionally gets parameters
      that specify default field value. }
    constructor Create(const AName: string);

    { Virtual constructor, that you can use to construct field instance when
      field class is known only at runtime.

      The idea is that in some cases, you need to create fields using
      variable like FieldClass: TVRMLFieldClass. See e.g. TVRMLInterfaceDeclaration,
      VRML 2.0 feature that simply requires this ability, also
      implementation of TVRMLSimpleMultField.Parse and
      TVRMLSimpleMultField.CreateItemBeforeParse.

      Later you can initialize such instance from string using it's Parse method.

      Note that some exceptional fields simply cannot work when initialized
      by this constructor: these are SFEnum and SFBitMask fields.
      They simply need to know their TSFEnum.EnumNames, or
      TSFBitMask.FlagNames + TSFBitMask.NoneString + TSFBitMask.AllString
      before they can be parsed. I guess that's one of the reasons why these
      field types were entirely removed from VRML 2.0. }
    constructor CreateUndefined(const AName: string); virtual;

    { Parse inits properties from Lexer.

      In this class, Parse only sets IsClause and IsClauseName:
      if we stand on "IS" clause (see VRML 2.0 spec about "IS" clause)
      and IsClauseAllowed then IsClause is set to @true and IsClauseName is set
      appropriately.

      Descendants should override this to read actual field contents.
      Always when overriding, call inherited first and check IsClause.
      If IsClause, then abort any further reading, as the field was
      specified using "IS" clause, so there's no actual value.

      Note that Lexer.NodeNameBinding is ignored by all
      TVRMLField descendants defined in this unit (it's used only
      by TSFNode and TMFNode). }
    procedure Parse(Lexer: TVRMLLexer; IsClauseAllowed: boolean); virtual;

    { O ile not EqualsDefaultValue to kazde pole bedzie zapisane jako jedna lub
      wiecej linii.
      (notka wewnetrzna dla implementacji tego modulu - nie probuj nigdy
      zapisac pol ktorych Name = '').

      NodeNameBinding has the same meaning as for TVRMLNode.SaveToStream,
      see there. It can be ignored, and in fact it is ignored by all
      TVRMLField descendants defined in this unit (it's used only
      by TSFNode and TMFNode). }
    procedure SaveToStream(Stream: TStream; const Indent: string;
      NodeNameBinding: TStringList);

    { zwraca zawsze false w tej klasie. Mozesz to przedefiniowac w podklasach
      aby SaveToStream nie zapisywalo do strumienia pol o wartosci domyslnej.

      Note that when IsClause, this should always return @false
      (as the field doesn't have any value, conceptually). }
    function EqualsDefaultValue: boolean; virtual;

    { @true if the SecondValue object has exactly the same type and properties.
      For this class, this returns just (SecondValue.Name = Name).

      All descendants (that add some property that should be compared)
      should override this like

@longCode(#
  Result := (inherited Equals(SecondValue, EqualityEpsilon)) and
    (SecondValue is TMyType) and
    (TMyType(SecondValue).MyProperty = MyProperty);
#)

      For varius floating-point fields in this unit:
      we compare each float using EqualityEpsilon,
      i.e. if the difference is < EqualityEpsilon then the floats
      are assumed equal. Pass EqualityEpsilon = 0.0
      to perform *exact* comparison (this case will be optimized
      in implementation, by using routines like CompareMem
      instead of comparing float-by-float).

      Note that this *doesn't* compare the default values of two fields
      instances. This compares only the current values of two fields
      instances, and eventually some other properties that affect
      parsing (like names for TSFEnum and TSFBitMask) or allowed
      future values (like TSFFloat.MustBeNonnegative).
    }
    function Equals(SecondValue: TVRMLField;
      const EqualityEpsilon: Single): boolean; virtual;

    { Is this an "exposedField" in VRML 97 ? }
    property Exposed: boolean read FExposed write FExposed;

    { This returns fieldType as for VRML interface declaration statements. }
    class function VRMLTypeName: string; virtual; abstract;

    { Parse only "IS" clause, if it's not present --- don't try to parse
      field value. }
    procedure ParseIsClause(Lexer: TVRMLLexer);

    { Does the field reference other field by "IS" clause.
      This is usually caused by specifying "IS" clause instead
      of field value in VRML file.

      Conceptually, we think of such field as "without any value".
      So Equals and EqualsDefaultValue will always return @false for such field.
      Yes, pretty much like in SQL the "null" value. }
    property IsClause: boolean read FIsClause;
    property IsClauseName: string read FIsClauseName;
  end;

  TVRMLFieldClass = class of TVRMLField;

  TObjectsListItem_2 = TVRMLField;
  {$I objectslist_2.inc}
  TVRMLFieldsListBase = TObjectsList_2;

  TVRMLFieldsList = class(TVRMLFieldsListBase)
  private
    function GetByName(const AName: string): TVRMLField;
  public
    {ByName to wygodne property pozwalajace operowac na polach
     podajac ich nazwe. Uwaga - jezeli nazwa nie istnieje - wyjatek
     Exception. }
    property ByName[const AName: string]:TVRMLField read GetByName;
    {NameIndex. Zwraca -1 jezeli nie znalazl.}
    function NameIndex(const AName: string): integer;
  end;

  TVRMLSingleField = class(TVRMLField)
  end;
  TVRMLSingleFieldClass = class of TVRMLSingleField;

  TObjectsListItem_1 = TVRMLSingleField;
  {$I ObjectsList_1.inc}
  TVRMLSingleFieldsList = TObjectsList_1;

  EVRMLMultFieldDifferentCount = class(Exception);

  TVRMLMultField = class(TVRMLField)
  public
    function Count: integer; virtual; abstract;

    { If SecondValue.Count <> Count, raises EVRMLMultFieldDifferentCount }
    procedure CheckCountEqual(SecondValue: TVRMLMultField);
  end;

  {pamietaj - lista MF fields moze miec zero elementow !
   MultFields w destruktorze zwalniaja wszystkie swoje RawItems.
   W kazdym typie potomnym TVRMLSimpleMultField MUSISZ zdefiniowac fItemClass
   w konstruktorze (inaczej bedzie = nil i bedzie error).

   Notka o wydajnosci implementacji : wydaje sie pociagajacym uproszczeniem
   zeby zapisac TVRMLSimpleMultField jako opakowanie na liste TVRMLSingleFieldsList.
   Ale takie rozwiazanie spowodowaloby ze dla dlugich pol MFField (a takie
   bedziemy czesto dostawac, tysiace vertexow w Coordinate3 to nic niezwyklego)
   bedziemy strasznie rozrzucali po pamieci duzo malenkich rekordow (b. duza
   fragmentacja pamieci, kiepska wydajnosc jej zarzadzaniem) no i, co bardzo
   wazne, nie bedziemy mogli uzywac vertex arrays OpenGL'a na tablicach
   vertexow i normali i texcoords. Szczegolnie ta druga wada moze powodowac
   bardzo duza strate szybkosci renderowania wiec nie mozemy sobie na to pozwolic.
   Tym bardziej ze gdy ladnie sobie wszystko zapiszemy uzywanie TDynArray
   moze nie byc wcale takie straszne.

   Co trzeba zrobic w podklasach aby zaimplementowac konkretne MFField ?
   @unorderedList(
     @item(W CreateUndefined zainicjowac FItemClass, utworzyc RawItems)

     @item(Pokryc RawItemsAdd)

     @item(
       If your ItemClass doesn't work 100% correctly when it's initialized
       by CreateUndefined, you may have to override CreateItemBeforeParse.
       Fortunately, VRML specification was careful to choose as multi-valued field
       types' only fields that can behave nicely when initialized by
       CreateUndefined (and in fact VRML 2.0 removed the "bad fields" entirely).)

     @item(
       Nie jest to zadnym wymaganiem ale zazwyczaj bedzie wygodnie jesli
       konstruktor bedzie pobieral jako argument array of Typ aby zainicjowac
       od razu swoja tablice.)
   ) }
  TVRMLSimpleMultField = class(TVRMLMultField)
  protected
    fItemClass: TVRMLSingleFieldClass;
    { CreateItemBeforeParse ma za zadanie utworzyc nowy obiekt klasy
      ItemClass ktorego wartosci moga byc niezdefiniwane bo za chwile
      zainicjujemy go wywolujac jego metode Parse. W tym wlasnie
      miejscu przydaje sie nam CreateUndefined. Default implementation
      calls simply ItemClass.CreateUndefined. }
    function CreateItemBeforeParse: TVRMLSingleField; virtual;
    { musisz pokryc ta metode w podklasie, powinna ona dodawac do
      RawItems na koncu Item (ktory na pewno jest klasy ItemClass).
      Pamietaj ze musisz sobie odpowiednio skopiowac zawartosc Item
      (a nie tylko jakis wskaznik do niej) bo obiekt Item moze zostac
      niedlugo zniszczony. }
    procedure RawItemsAdd(Item: TVRMLSingleField); virtual abstract;
  protected
    { nie ma potrzeby definiowania SaveToStreamValue w podklasach,
      zdefiniuj tylko RawItemToString(i) ktore zamienia RawItems[i]
      na string ktory moze byc zapisany jako wartosc tego pola w VRMLu.
      W niniejszej klasie zajmujemy sie wszystkim.

      Jezeli chcesz, mozesz w podklasie pokryc implementacje
      SaveToStreamDoNewLineAfterRawItem - w tej klasie zawsze odpowiada
      true. Ale zwroc uwage ze wyniki zwracane przez
      SaveToStreamDoNewLineAfterRawItem moga byc niekiedy ignorowane
      (czasami po prostu w tej klasie wiemy ze NA PEWNO tak jak robimy
      bedzie ladniej wygladalo; bo tak czy siak, tu chodzi tylko o estetyke) }
    procedure SaveToStreamValue(Stream: TStream; const Indent: string;
      NodeNameBinding: TStringList); override;
    function RawItemToString(ItemNum: integer): string; virtual; abstract;
    function SaveToStreamDoNewLineAfterRawItem(ItemNum: integer): boolean; virtual;
  public
    { kazda podklasa musi w konstruktorze utworzyc sobie ta tablice
      (w destruktorze my samy juz zajmiemy sie zwalnianiem tej tablicy) }
    RawItems: TDynArrayBase;

    { po prostu RawItems.Count }
    function Count: integer; override;

    { wszystkie elementy jakie beda trafiac do RawItemsAdd beda tej klasy.
      Nie jest tu zdefiniowana zaleznosc miedzy elementami tej klasy a
      elementami tablicy RawItems - musisz w kazdej podklasie okreslic
      ta zaleznosc definiujac RawItemsAdd. }
    property ItemClass: TVRMLSingleFieldClass read fItemClass;

    { nie ma potrzeby definiowania Parse w zadnej podklasie pola MF.
      Tutejsze Parse dziala dla kazdego pola typu MF, uzywajac Parse
      klasy ItemClass. }
    procedure Parse(Lexer: TVRMLLexer; IsClauseAllowed: boolean); override;

    destructor Destroy; override;

    { In addition to inherited(Equals), this also checks that
      Count and ItemClass are equal. All descendants must check
      for equality every item on SecondValue.Items[I] and Items[I]. }
    function Equals(SecondValue: TVRMLField;
      const EqualityEpsilon: Single): boolean; override;
  end;

{ single value fields ----------------------------------------------------- }

  { SFBitMask field.

    TSFBitMask is one of the exceptional field types that cannot
    be 100% correctly initialized by CreateUndefined, since
    EnumNames will be left undefined. }
  TSFBitMask = class(TVRMLSingleField)
  private
    fAllString, fNoneString: string;
    fFlagNames: TStringList;
    {specyfikacja VRML'a 1.0 gwarantuje ze SFBitMask ma 32 lub mniej flag,
     zreszta zdefiniowane pola nie wychodza ponad 3 flagi.
     W VRML'u 97 w ogole nie ma typu pola SFBitMask.}
    fFlags: set of 0..31;
    function GetFlags(i: integer): boolean;
    procedure SetFlags(i: integer; value: boolean);
    function GetFlagNames(i: integer): string;
  protected
    procedure SaveToStreamValue(Stream: TStream; const Indent: string;
      NodeNameBinding: TStringList); override;
  public
    {Flags okresla wartosci wszystkich flag - pytaj go o liczby z przedzialu
     0..FlagsCount-1}
    property Flags[i: integer]:boolean read GetFlags write SetFlags;
    function FlagsCount: integer;
    property FlagNames[i: integer]:string read GetFlagNames;

    {AllString i NoneString : specjalne flagi ktorych uzycie powoduje
     odpowiednio zaznaczenie wszystkich flag i nie zaznaczanie zadnej.
     AllString istnieje tylko jezeli jest podana wartosc <> '',
     NoneString musi byc zawsze <> '' (zawsze musi byc podany;
     to nam pozwala myslec bardziej prosto o tych flagach -
     kazda ich postac jest dozwolona, kazda mozna odczytac i zapisac
     do pliku).
     Nie ma sensu mieszania ich z innymi flagami (ALL | ze wszystkim daje
     ciagle ALL, a NONE z czymkolwiek daje to cokolwiek) ale jest to
     dopuszczalne skladniowo (tzn. parser i lekser to przyjma),
     ALL jest zazwyczaj tylko wygodnym skrotem ale istnienie flagi NONE
     ma zasadnicze znaczenie : poniewaz SFBitMask zawsze musi bc zapisane
     jako przynajmniej jedna flaga, to jedynym sposobem aby zapisanie
     wszystkich flag = false jest uzycie NONE.  }
    property AllString: string read fAllString;
    property NoneString: string read fNoneString;

    procedure Parse(Lexer: TVRMLLexer; IsClauseAllowed: boolean); override;

    { zwraca true jesli wszystkie flagi sa = value }
    function AreAllFlags(value: boolean): boolean;

    { pamietaj - tablica AFFlagNames i AFlags (poczatkowa wartosc Flags)
      musza miec tyle samo elementow, ew. AFlags moze byc dluzsza (dodatkowe
      elementy beda ignorowane) }
    constructor Create(const AName: string; const AFlagNames: array of string;
      const ANoneString, AAllString: string; const AFlags: array of boolean);

    destructor Destroy; override;

    function Equals(SecondValue: TVRMLField;
      const EqualityEpsilon: Single): boolean; override;

    procedure Assign(Source: TPersistent); override;

    class function VRMLTypeName: string; override;
  end;

  TSFBool = class(TVRMLSingleField)
  protected
    procedure SaveToStreamValue(Stream: TStream; const Indent: string;
      NodeNameBinding: TStringList); override;
  public
    constructor Create(const AName: string; const AValue: boolean);

    Value: boolean;

    DefaultValue: boolean;
    DefaultValueExists: boolean;

    procedure Parse(Lexer: TVRMLLexer; IsClauseAllowed: boolean); override;
    function EqualsDefaultValue: boolean; override;
    function Equals(SecondValue: TVRMLField;
      const EqualityEpsilon: Single): boolean; override;
    procedure Assign(Source: TPersistent); override;

    class function VRMLTypeName: string; override;
  end;

  TSFColor = class(TVRMLSingleField)
  protected
    procedure SaveToStreamValue(Stream: TStream; const Indent: string;
      NodeNameBinding: TStringList); override;
  public
    constructor Create(const AName: string; const AValue: TVector3Single);

    Value: TVector3Single;

    DefaultValue: TVector3Single;
    DefaultValueExists: boolean;

    procedure Parse(Lexer: TVRMLLexer; IsClauseAllowed: boolean); override;
    function EqualsDefaultValue: boolean; override;
    function Equals(SecondValue: TVRMLField;
      const EqualityEpsilon: Single): boolean; override;
    procedure AssignLerp(const A: Single; Value1, Value2: TSFColor);
    procedure Assign(Source: TPersistent); override;

    class function VRMLTypeName: string; override;
  end;

  { SFEnum field.

    TSFEnum is one of the exceptional field types that cannot
    be 100% correctly initialized by CreateUndefined, since
    EnumNames will be left undefined. }
  TSFEnum = class(TVRMLSingleField)
  private
    fEnumNames: TStringList;
    function GetEnumNames(i: integer): string;
  protected
    procedure SaveToStreamValue(Stream: TStream; const Indent: string;
      NodeNameBinding: TStringList); override;
  public
    constructor Create(const AName: string;
      const AEnumNames: array of string; const AValue: integer);
    destructor Destroy; override;

    Value: integer; { wartosc z 0..EnumCount-1; domyslnie 0 }

    DefaultValue: integer;
    DefaultValueExists: boolean;

    property EnumNames[i: integer]:string read GetEnumNames;
    function EnumNamesCount: integer;
    procedure Parse(Lexer: TVRMLLexer; IsClauseAllowed: boolean); override;
    function EqualsDefaultValue: boolean; override;
    function Equals(SecondValue: TVRMLField;
      const EqualityEpsilon: Single): boolean; override;
    procedure Assign(Source: TPersistent); override;

    class function VRMLTypeName: string; override;
  end;

  TSFFloat = class(TVRMLSingleField)
  private
    FMustBeNonnegative: boolean;
    FValue: Single;
    procedure SetValue(const AValue: Single);
  protected
    procedure SaveToStreamValue(Stream: TStream; const Indent: string;
      NodeNameBinding: TStringList); override;
  public
    constructor Create(const AName: string; const AValue: Single); overload;
    constructor Create(const AName: string; const AValue: Single;
      AMustBeNonnegative: boolean); overload;

    property Value: Single read FValue write SetValue;

    DefaultValue: Single;
    DefaultValueExists: boolean;

    { jezeli true to przy probie ustawienia Value na X gdzie X < 0
      ustawi Value := -X (a wiec NIE robi clamp do 0 w rodzaju Value := Max(0, X)
      tylko Value := Abs(X); to jest cos dobrego dla np. Sphere.FdRadius). }
    property MustBeNonnegative: boolean read FMustBeNonnegative default false;

    procedure Parse(Lexer: TVRMLLexer; IsClauseAllowed: boolean); override;
    function EqualsDefaultValue: boolean; override;
    function Equals(SecondValue: TVRMLField;
      const EqualityEpsilon: Single): boolean; override;
    procedure AssignLerp(const A: Single; Value1, Value2: TSFFloat);
    procedure Assign(Source: TPersistent); override;

    class function VRMLTypeName: string; override;
  end;

  { This is SFTime VRML field.
    VRML requires this to be stored as double-precision float,
    so I don't use TSFFloat for this. }
  TSFTime = class(TVRMLSingleField)
  private
    FValue: Double;
    procedure SetValue(const AValue: Double);
  protected
    procedure SaveToStreamValue(Stream: TStream; const Indent: string;
      NodeNameBinding: TStringList); override;
  public
    constructor Create(const AName: string; const AValue: Double);

    property Value: Double read FValue write SetValue;

    DefaultValue: Double;
    DefaultValueExists: boolean;

    procedure Parse(Lexer: TVRMLLexer; IsClauseAllowed: boolean); override;
    function EqualsDefaultValue: boolean; override;
    function Equals(SecondValue: TVRMLField;
      const EqualityEpsilon: Single): boolean; override;
    procedure AssignLerp(const A: Double; Value1, Value2: TSFTime);
    procedure Assign(Source: TPersistent); override;

    class function VRMLTypeName: string; override;
  end;

  TSFImage = class(TVRMLSingleField)
  protected
    procedure SaveToStreamValue(Stream: TStream; const Indent: string;
      NodeNameBinding: TStringList); override;
  public

    { Value is owned by this object - i.e. in destructor we do Value.Free.

      Value may be IsNull, and then we know that there is no image
      recorded in this field. Value may never be nil.
      Remember --- Value is freed by this object, but if you're altering it in any
      other way, you're responsible for good memory managing. }
    Value: TImage;

    { @param(AValue is the initial value for Value.

        Note - our constructor COPIES passed reference AValue, not it's contents
        (I mean, we do Value := AValue, NOT Value := ImageCopy(AValue),
        so don't Free image given to us (at least, don't do this without clearing
        our Value field)).
        You can pass AValue = nil, then Value will be inited to null image
        TRGBImage.Create.) }
    constructor Create(const AName: string; const AValue: TImage);
    constructor CreateUndefined(const AName: string); override;

    destructor Destroy; override;

    procedure Parse(Lexer: TVRMLLexer; IsClauseAllowed: boolean); override;

    function Equals(SecondValue: TVRMLField;
      const EqualityEpsilon: Single): boolean; override;

    procedure Assign(Source: TPersistent); override;

    class function VRMLTypeName: string; override;
  end;

  TSFLong = class(TVRMLSingleField)
  private
    FMustBeNonnegative: boolean;
    FValue: Longint;
    procedure SetValue(const AValue: Longint);
  protected
    procedure SaveToStreamValue(Stream: TStream; const Indent: string;
      NodeNameBinding: TStringList); override;
  public
    constructor Create(const AName: string; const AValue: Longint); overload;
    constructor Create(const AName: string; const AValue: Longint;
      AMustBeNonnegative: boolean); overload;

    property Value: Longint read FValue write SetValue;

    DefaultValue: Longint;
    DefaultValueExists: boolean;

    { komentarz - jak dla TSFFloat.MustBeNonnegative }
    property MustBeNonnegative: boolean read FMustBeNonnegative; { = false }
    procedure Parse(Lexer: TVRMLLexer; IsClauseAllowed: boolean); override;
    function EqualsDefaultValue: boolean; override;
    function Equals(SecondValue: TVRMLField;
      const EqualityEpsilon: Single): boolean; override;
    procedure Assign(Source: TPersistent); override;

    class function VRMLTypeName: string; override;
  end;

  TSFInt32 = class(TSFLong)
  public
    class function VRMLTypeName: string; override;
  end;

  TSFMatrix = class(TVRMLSingleField)
  protected
    procedure SaveToStreamValue(Stream: TStream; const Indent: string;
      NodeNameBinding: TStringList); override;
  public
    constructor Create(const AName: string; const AMatrix: TMatrix4Single);

    Matrix: TMatrix4Single;

    procedure Parse(Lexer: TVRMLLexer; IsClauseAllowed: boolean); override;
    function Equals(SecondValue: TVRMLField;
      const EqualityEpsilon: Single): boolean; override;
    procedure AssignLerp(const A: Single; Value1, Value2: TSFMatrix);
    procedure Assign(Source: TPersistent); override;

    class function VRMLTypeName: string; override;
  end;

  TSFRotation = class(TVRMLSingleField)
  protected
    procedure SaveToStreamValue(Stream: TStream; const Indent: string;
      NodeNameBinding: TStringList); override;
    function GetValue: TVector4Single;
    procedure SetValue(const AValue: TVector4Single);
  public
    constructor Create(const AName: string; const AnAxis: TVector3Single; const ARotationRad: Single);

    Axis: TVector3Single;
    RotationRad: Single;
    property Value: TVector4Single read GetValue write SetValue;

    procedure Parse(Lexer: TVRMLLexer; IsClauseAllowed: boolean); override;
    { rotate point pt around self }
    function RotatedPoint(const pt: TVector3Single): TVector3Single;
    function Equals(SecondValue: TVRMLField;
      const EqualityEpsilon: Single): boolean; override;
    procedure AssignLerp(const A: Single; Value1, Value2: TSFRotation);
    procedure Assign(Source: TPersistent); override;

    class function VRMLTypeName: string; override;
  end;

  TSFString = class(TVRMLSingleField)
  protected
    procedure SaveToStreamValue(Stream: TStream; const Indent: string;
      NodeNameBinding: TStringList); override;
  public
    constructor Create(const AName: string; const AValue: string);

    Value: string;

    DefaultValue: string;
    DefaultValueExists: boolean;

    procedure Parse(Lexer: TVRMLLexer; IsClauseAllowed: boolean); override;
    function EqualsDefaultValue: boolean; override;
    function Equals(SecondValue: TVRMLField;
      const EqualityEpsilon: Single): boolean; override;
    procedure Assign(Source: TPersistent); override;

    class function VRMLTypeName: string; override;
  end;

  TSFVec2f = class(TVRMLSingleField)
  protected
    procedure SaveToStreamValue(Stream: TStream; const Indent: string;
      NodeNameBinding: TStringList); override;
  public
    constructor Create(const AName: string; const AValue: TVector2Single);

    Value: TVector2Single;

    DefaultValue: TVector2Single;
    DefaultValueExists: boolean;

    procedure Parse(Lexer: TVRMLLexer; IsClauseAllowed: boolean); override;
    function EqualsDefaultValue: boolean; override;
    function Equals(SecondValue: TVRMLField;
      const EqualityEpsilon: Single): boolean; override;
    procedure AssignLerp(const A: Single; Value1, Value2: TSFVec2f);
    procedure Assign(Source: TPersistent); override;

    class function VRMLTypeName: string; override;
  end;

  TSFVec3f = class(TVRMLSingleField)
  protected
    procedure SaveToStreamValue(Stream: TStream; const Indent: string;
      NodeNameBinding: TStringList); override;
  public
    constructor Create(const AName: string; const AValue: TVector3Single);

    Value: TVector3Single;

    DefaultValue: TVector3Single;
    DefaultValueExists: boolean;

    procedure Parse(Lexer: TVRMLLexer; IsClauseAllowed: boolean); override;
    function EqualsDefaultValue: boolean; override;
    function Equals(SecondValue: TVRMLField;
      const EqualityEpsilon: Single): boolean; override;
    procedure AssignLerp(const A: Single; Value1, Value2: TSFVec3f);
    procedure Assign(Source: TPersistent); override;

    class function VRMLTypeName: string; override;
  end;

{ ---------------------------------------------------------------------------- }
{ @section(Multiple value fields) }

{ Internal comment for DefaultValue* field:

  pole DefaultValuesCount
  moze miec w tej chwili trzy wartosci : -1 (nie ma (nie jest znana) domyslnej
  wartosci dla pola), 0 (domyslna wartosc pola to 0 elementow), 1 (domylna
  wartosc pola to 1 element o wartosci DefaultValue).

  CreateUndefined sets DefaultValuesCount to -1. }

  { }
  TMFColor = class(TVRMLSimpleMultField)
  private
    DefaultValuesCount: integer;
    DefaultValue: TVector3Single;
  protected
    function RawItemToString(ItemNum: integer): string; override;
  public
    function Items: TDynVector3SingleArray;
    procedure RawItemsAdd(Item: TVRMLSingleField); override;
    constructor Create(const AName: string;
      const InitialContent: array of TVector3Single);
    constructor CreateUndefined(const AName: string); override;

    function EqualsDefaultValue: boolean; override;
    function Equals(SecondValue: TVRMLField;
      const EqualityEpsilon: Single): boolean; override;
    { @raises(EVRMLMultFieldDifferentCount When Value1.Count <> Value2.Count) }
    procedure AssignLerp(const A: Single; Value1, Value2: TMFColor);
    procedure Assign(Source: TPersistent); override;

    class function VRMLTypeName: string; override;
  end;

  TMFLong = class(TVRMLSimpleMultField)
  private
    DefaultValuesCount: integer;
    DefaultValue: Longint;
  protected
    function RawItemToString(ItemNum: integer): string; override;
    function SaveToStreamDoNewLineAfterRawItem(ItemNum: integer): boolean; override;
  public
    { jesli SaveToStreamLineUptoMinusOne to w tej klasie przedefiniujemy
      SaveToStreamDoNewLineAfterRawItem zeby odpowiadal true tylko gdy
      indeksujemy liczby ujemne. W ten sposob mozesz sprawic ze np.
      IndexedFaceSet.coordIndex sa ladnie wypisywane. }
    SaveToStreamLineUptoNegative: boolean; { = false }

    function Items: TDynLongintArray;
    procedure RawItemsAdd(Item: TVRMLSingleField); override;
    constructor Create(const AName: string; const InitialContent: array of Longint);
    constructor CreateMFLong(const AName: string; const InitialContent: array of Longint;
      const ASaveToStreamLineUptoNegative: boolean);
    constructor CreateUndefined(const AName: string); override;

    function EqualsDefaultValue: boolean; override;
    function Equals(SecondValue: TVRMLField;
      const EqualityEpsilon: Single): boolean; override;
    procedure Assign(Source: TPersistent); override;

    class function VRMLTypeName: string; override;
  end;

  TMFInt32 = class(TMFLong)
  public
    class function VRMLTypeName: string; override;
  end;

  TMFVec2f = class(TVRMLSimpleMultField)
  private
    DefaultValuesCount: integer;
    DefaultValue: TVector2Single;
  protected
    function RawItemToString(ItemNum: integer): string; override;
  public
    function Items: TDynVector2SingleArray;
    procedure RawItemsAdd(Item: TVRMLSingleField); override;
    constructor Create(const AName: string; const InitialContent: array of TVector2Single);
    constructor CreateUndefined(const AName: string); override;

    function EqualsDefaultValue: boolean; override;
    function Equals(SecondValue: TVRMLField;
      const EqualityEpsilon: Single): boolean; override;
    { @raises(EVRMLMultFieldDifferentCount When Value1.Count <> Value2.Count) }
    procedure AssignLerp(const A: Single; Value1, Value2: TMFVec2f);
    procedure Assign(Source: TPersistent); override;

    class function VRMLTypeName: string; override;
  end;

  TMFVec3f = class(TVRMLSimpleMultField)
  private
    DefaultValuesCount: integer;
    DefaultValue: TVector3Single;
  protected
    function RawItemToString(ItemNum: integer): string; override;
  public
    function Items: TDynVector3SingleArray;
    procedure RawItemsAdd(Item: TVRMLSingleField); override;
    constructor Create(const AName: string; const InitialContent: array of TVector3Single);
    constructor CreateUndefined(const AName: string); override;

    function EqualsDefaultValue: boolean; override;
    function Equals(SecondValue: TVRMLField;
      const EqualityEpsilon: Single): boolean; override;
    { @raises(EVRMLMultFieldDifferentCount When Value1.Count <> Value2.Count) }
    procedure AssignLerp(const A: Single; Value1, Value2: TMFVec3f);
    procedure Assign(Source: TPersistent); override;

    class function VRMLTypeName: string; override;
  end;

  TMFRotation = class(TVRMLSimpleMultField)
  private
    DefaultValuesCount: Integer;
    DefaultValue: TVector4Single;
  protected
    function RawItemToString(ItemNum: Integer): string; override;
  public
    function Items: TDynVector4SingleArray;
    procedure RawItemsAdd(Item: TVRMLSingleField); override;
    constructor Create(const AName: string;
      const InitialContent: array of TVector4Single);
    constructor CreateUndefined(const AName: string); override;

    function EqualsDefaultValue: boolean; override;
    function Equals(SecondValue: TVRMLField;
      const EqualityEpsilon: Single): boolean; override;
    { @raises(EVRMLMultFieldDifferentCount When Value1.Count <> Value2.Count) }
    procedure AssignLerp(const A: Single; Value1, Value2: TMFRotation);
    procedure Assign(Source: TPersistent); override;

    class function VRMLTypeName: string; override;
  end;

  TMFFloat = class(TVRMLSimpleMultField)
  private
    DefaultValuesCount: integer;
    DefaultValue: Single;
  protected
    function RawItemToString(ItemNum: integer): string; override;
  public
    function Items: TDynSingleArray;
    procedure RawItemsAdd(Item: TVRMLSingleField); override;
    constructor Create(const AName: string;
      const InitialContent: array of Single);
    constructor CreateUndefined(const AName: string); override;

    function EqualsDefaultValue: boolean; override;
    function Equals(SecondValue: TVRMLField;
      const EqualityEpsilon: Single): boolean; override;
    { @raises(EVRMLMultFieldDifferentCount When Value1.Count <> Value2.Count) }
    procedure AssignLerp(const A: Single; Value1, Value2: TMFFloat);
    procedure Assign(Source: TPersistent); override;

    class function VRMLTypeName: string; override;
  end;

  TMFTime = class(TVRMLSimpleMultField)
  private
    DefaultValuesCount: integer;
    DefaultValue: Double;
  protected
    function RawItemToString(ItemNum: integer): string; override;
  public
    function Items: TDynDoubleArray;
    procedure RawItemsAdd(Item: TVRMLSingleField); override;
    constructor Create(const AName: string;
      const InitialContent: array of Double);
    constructor CreateUndefined(const AName: string); override;

    function EqualsDefaultValue: boolean; override;
    function Equals(SecondValue: TVRMLField;
      const EqualityEpsilon: Single): boolean; override;
    { @raises(EVRMLMultFieldDifferentCount When Value1.Count <> Value2.Count) }
    procedure AssignLerp(const A: Double; Value1, Value2: TMFTime);
    procedure Assign(Source: TPersistent); override;

    class function VRMLTypeName: string; override;
  end;

  TMFString = class(TVRMLSimpleMultField)
  private
    DefaultValuesCount: integer;
    DefaultValue: string;
  protected
    function RawItemToString(ItemNum: integer): string; override;
  public
    function Items: TDynStringArray;
    procedure RawItemsAdd(Item: TVRMLSingleField); override;
    constructor Create(const AName: string; const InitialContent: array of string);
    constructor CreateUndefined(const AName: string); override;

    function EqualsDefaultValue: boolean; override;
    function Equals(SecondValue: TVRMLField;
      const EqualityEpsilon: Single): boolean; override;
    procedure Assign(Source: TPersistent); override;

    class function VRMLTypeName: string; override;
  end;

  { Stores information about available VRML field classes.
    The only use for now is to make a mapping from VRML field name to
    actual class (needed by VRML interface declarations). }
  TVRMLFieldsManager = class
  private
    Registered: TStringList;
  public
    constructor Create;
    destructor Destroy; override;

    procedure RegisterClass(AClass: TVRMLFieldClass);
    procedure RegisterClasses(const Classes: array of TVRMLFieldClass);

    { Return field class for given name. Returns @nil if not found. }
    function FieldTypeNameToClass(const TypeName: string): TVRMLFieldClass;
  end;

var
  VRMLFieldsManager: TVRMLFieldsManager;

{$undef read_interface}

implementation

uses Math, VRMLErrors;

{$define read_implementation}
{$I objectslist_1.inc}
{$I objectslist_2.inc}

{ TVRMLField ------------------------------------------------------------- }

constructor TVRMLField.Create(const AName: string);
begin
  CreateUndefined(AName);
end;

constructor TVRMLField.CreateUndefined(const AName: string);
begin
  inherited Create;
  FName := AName;
end;

procedure TVRMLField.SaveToStream(Stream: TStream; const Indent: string;
  NodeNameBinding: TStringList);
begin
  Assert(Name <> '',
    'VRML field name must be defined to allow saving field to stream');
  if not EqualsDefaultValue then
  begin
    WriteStr(Stream, Indent + Name + ' ');
    { We depend here on the fact that EqualsDefaultValue is always @false
      when IsClause, otherwise fields with IsClause could be omitted by
      check "if not EqualsDefaultValue then" above. }
    if IsClause then
      WriteStr(Stream, 'IS ' + IsClauseName) else
      SaveToStreamValue(Stream, Indent, NodeNameBinding);
    WriteStr(Stream, nl);
  end;
end;

function TVRMLField.EqualsDefaultValue: boolean;
begin
  Result := false;
end;

function TVRMLField.Equals(SecondValue: TVRMLField;
  const EqualityEpsilon: Single): boolean;
begin
  Result := (not IsClause) and (SecondValue.Name = Name);
end;

procedure TVRMLField.ParseIsClause(Lexer: TVRMLLexer);
begin
  FIsClause := Lexer.TokenIsKeyword(vkIS);
  if FIsClause then
  begin
    Lexer.NextToken;
    FIsClauseName := Lexer.TokenName;
    Lexer.NextToken;
  end;
end;

procedure TVRMLField.Parse(Lexer: TVRMLLexer; IsClauseAllowed: boolean);
begin
  if IsClauseAllowed then
    ParseIsClause(Lexer) else
    FIsClause := false;
end;

procedure TVRMLField.VRMLFieldAssignCommon(Source: TVRMLField);
begin
  FName := Source.Name;
  FExposed := Source.Exposed;
  FIsClause := Source.IsClause;
  FIsClauseName := Source.IsClauseName;
end;

{ TVRMLFieldsList ------------------------------------------------------------- }

function TVRMLFieldsList.NameIndex(const AName: string): integer;
begin
 for result := 0 to Count-1 do
  if Items[result].Name = AName then exit;
 result := -1;
end;

function TVRMLFieldsList.GetByName(const AName: string): TVRMLField;
var i: integer;
begin
 i := NameIndex(AName);
 if i >= 0 then
  result := Items[i] else
  raise Exception.Create('Field name '+AName+' not found');
end;

{ TVRMLMultField ------------------------------------------------------------- }

procedure TVRMLMultField.CheckCountEqual(SecondValue: TVRMLMultField);
begin
 if SecondValue.Count <> Count then
  raise EVRMLMultFieldDifferentCount.CreateFmt(
    'Different length of multiple-value fields "%s" and "%s": "%d" and "%d"',
    [ Name,
      SecondValue.Name,
      Count,
      SecondValue.Count ]);
end;

{ TVRMLSimpleMultField ------------------------------------------------------- }

destructor TVRMLSimpleMultField.Destroy;
begin
 RawItems.Free;
 inherited;
end;

function TVRMLSimpleMultField.Count: integer;
begin result := RawItems.Count end;

function TVRMLSimpleMultField.CreateItemBeforeParse: TVRMLSingleField;
begin
 result := ItemClass.CreateUndefined('');
end;

procedure TVRMLSimpleMultField.Parse(
  Lexer: TVRMLLexer; IsClauseAllowed: boolean);
var SingleItem: TVRMLSingleField;
begin
  inherited;

  RawItems.SetLength(0);

  if IsClause then Exit;

  RawItems.AllowedCapacityOverflow := 100;
  SingleItem := nil;
  try
   SingleItem := CreateItemBeforeParse;

   if Lexer.Token = vtOpenSqBracket then
   begin
    Lexer.NextToken;

    while Lexer.Token <> vtCloseSqBracket do
    {zawsze w tym miejscu albo stoimy na "]" albo na kolejnej wartosci pola SF}
    begin
     SingleItem.Parse(Lexer, false);
     RawItemsAdd(SingleItem);

     if Lexer.Token = vtCloseSqBracket then break;

     if Lexer.VRMLVerMajor < 2 then
     begin
       Lexer.CheckTokenIs(vtComma);
       Lexer.NextToken;
     end;
    end;

    { Our handling of commas is specified by VRML 1.0 spec:
      - When the list has no items, "[]" is allowed but "[,]" is not.
      - When there are some items on the list, the last item *may*
        be followed by a comma.
      For VRML 2.0 this all doesn't matter, comma is just a whitespace
      and Lexer will never return such token. }

    Lexer.NextToken;
   end else
   begin
    {one single field - not enclosed in [] brackets}
    SingleItem.Parse(Lexer, false);
    RawItemsAdd(SingleItem);
   end;

  finally
    FreeAndNil(SingleItem);
    RawItems.AllowedCapacityOverflow := 4;
  end;
end;

procedure TVRMLSimpleMultField.SaveToStreamValue(Stream: TStream;
  const Indent: string; NodeNameBinding: TStringList);
var i: integer;
    WriteIndentNextTime: boolean;
begin
 { kod ogolny generowalby poprawne wartosci takze dla RawItems.Count = 0 i 1.
   Ale zalatwiam je specjalnym kodem dla estetyki. }
 if RawItems.Count = 0 then
  WriteStr(Stream, '[]') else
 if RawItems.Count = 1 then
  WriteStr(Stream, RawItemToString(0)) else
 begin
  WriteStr(Stream, '[' +nl);
  WriteIndentNextTime := true;
  for i := 0 to RawItems.Count-1 do
  begin
   if WriteIndentNextTime then WriteStr(Stream, Indent +IndentIncrement);
   WriteStr(Stream, RawItemToString(i) +',');
   {za ostatnim elementem listy zawsze piszemy newline,
    bez wzgledu na wynik SaveToStreamDoNewLineAfterRawItem}
   if (i = RawItems.Count-1) or SaveToStreamDoNewLineAfterRawItem(i) then
     begin WriteStr(Stream, nl); WriteIndentNextTime := true end else
     begin WriteStr(Stream, ' '); WriteIndentNextTime := false; end;
  end;
  WriteStr(Stream, Indent +']');
 end;
end;

function TVRMLSimpleMultField.SaveToStreamDoNewLineAfterRawItem(ItemNum: integer): boolean;
begin
 result := true;
end;

function TVRMLSimpleMultField.Equals(SecondValue: TVRMLField;
  const EqualityEpsilon: Single): boolean;
begin
 Result := (inherited Equals(SecondValue, EqualityEpsilon)) and
   (SecondValue is TVRMLSimpleMultField) and
   (TVRMLSimpleMultField(SecondValue).Count = Count) and
   (TVRMLSimpleMultField(SecondValue).ItemClass = ItemClass);
end;

{ simple helpful parsing functions ---------------------------------------- }

{ This returns Float, not just Single, because it's used by TSFTime
  that wants double-precision preserved. }
function ParseFloat(Lexer: TVRMLLexer): Float;
begin
  Lexer.CheckTokenIs(TokenNumbers, 'float number');
  result := Lexer.TokenFloat;
  Lexer.NextToken;
end;

procedure ParseVector(var Vector: array of Single; Lexer: TVRMLLexer);
var i: integer;
begin
 for i := 0 to High(Vector) do Vector[i] := ParseFloat(Lexer);
end;

function ParseLongWord(Lexer: TVRMLLexer): LongWord;
begin
 Lexer.CheckTokenIs(vtInteger);
 result := Lexer.TokenInteger;
 Lexer.NextToken;
end;

{ TSFBool -------------------------------------------------------------------- }

constructor TSFBool.Create(const AName: string; const AValue: boolean);
begin
  inherited Create(AName);

  Value := AValue;
  DefaultValue := AValue;
  DefaultValueExists := true;
end;

procedure TSFBool.Parse(Lexer: TVRMLLexer; IsClauseAllowed: boolean);

  procedure VRML2BooleanIntegerNonFatalError;
  begin
    if Lexer.VRMLVerMajor >= 2 then
      VRMLNonFatalError('In VRML >= 2.0 you cannot express boolean values ' +
        'as 0 (instead of FALSE) or 1 (instead of TRUE)');
  end;

const
  SBoolExpected = 'boolean constant (TRUE, FALSE)';
begin
  inherited;
  if IsClause then Exit;

  Lexer.CheckTokenIs([vtKeyword, vtInteger], SBoolExpected);
  if Lexer.Token = vtKeyword then
  begin
   if Lexer.TokenKeyword = vkTrue then Value := true else
    if Lexer.TokenKeyword = vkFalse then Value := false else
     raise EVRMLParserError.Create(Lexer,
       'Expected '+SBoolExpected+', got '+Lexer.DescribeToken);
  end else
  begin
   if Lexer.TokenInteger = 1 then
   begin
     Value := true;
     VRML2BooleanIntegerNonFatalError;
   end else
   if Lexer.TokenInteger = 0 then
   begin
     Value := false;
     VRML2BooleanIntegerNonFatalError;
   end else
     raise EVRMLParserError.Create(Lexer,
       'Expected '+SBoolExpected+', got '+Lexer.DescribeToken);
  end;
  Lexer.NextToken;
end;

procedure TSFBool.SaveToStreamValue(Stream: TStream;
  const Indent: string; NodeNameBinding: TStringList);
begin
 if Value then WriteStr(Stream, VRMLKeywords[vkTrue]) else
               WriteStr(Stream, VRMLKeywords[vkFalse])
end;

function TSFBool.EqualsDefaultValue: boolean;
begin
 result := (not IsClause) and DefaultValueExists and (DefaultValue = Value);
end;

function TSFBool.Equals(SecondValue: TVRMLField;
  const EqualityEpsilon: Single): boolean;
begin
 Result := (inherited Equals(SecondValue, EqualityEpsilon)) and
   (SecondValue is TSFBool) and
   (TSFBool(SecondValue).Value = Value);
end;

procedure TSFBool.Assign(Source: TPersistent);
begin
 if Source is TSFBool then
 begin
  DefaultValue       := TSFBool(Source).DefaultValue;
  DefaultValueExists := TSFBool(Source).DefaultValueExists;
  Value              := TSFBool(Source).Value;
  VRMLFieldAssignCommon(TVRMLField(Source));
 end else
  inherited;
end;

class function TSFBool.VRMLTypeName: string;
begin
  Result := 'SFBool';
end;

{ TSFColor ------------------------------------------------------------------- }

constructor TSFColor.Create(const AName: string; const AValue: TVector3Single);
begin
  inherited Create(AName);

  Value := AValue;
  DefaultValue := AValue;
  DefaultValueExists := true;
end;

procedure TSFColor.Parse(Lexer: TVRMLLexer; IsClauseAllowed: boolean);
begin
  inherited;
  if IsClause then Exit;

  ParseVector(Value, Lexer);
end;

procedure TSFColor.SaveToStreamValue(Stream: TStream;
  const Indent: string; NodeNameBinding: TStringList);
begin
  WriteStr(Stream, VectorToRawStr(Value));
end;

function TSFColor.EqualsDefaultValue: boolean;
begin
  result := (not IsClause) and
    DefaultValueExists and (DefaultValue[0] = Value[0])
                       and (DefaultValue[1] = Value[1])
                       and (DefaultValue[2] = Value[2]);
end;

function TSFColor.Equals(SecondValue: TVRMLField;
  const EqualityEpsilon: Single): boolean;
begin
 Result := (inherited Equals(SecondValue, EqualityEpsilon)) and
   (SecondValue is TSFColor) and
   VectorsEqual(TSFColor(SecondValue).Value, Value, EqualityEpsilon);
end;

procedure TSFColor.AssignLerp(const A: Single; Value1, Value2: TSFColor);
begin
 Value := VLerp(A, Value1.Value, Value2.Value);
end;

procedure TSFColor.Assign(Source: TPersistent);
begin
 if Source is TSFColor then
 begin
  DefaultValue       := TSFColor(Source).DefaultValue;
  DefaultValueExists := TSFColor(Source).DefaultValueExists;
  Value              := TSFColor(Source).Value;
  VRMLFieldAssignCommon(TVRMLField(Source));
 end else
  inherited;
end;

class function TSFColor.VRMLTypeName: string;
begin
  Result := 'SFColor';
end;

{ TSFFloat ------------------------------------------------------------------- }

procedure TSFFloat.SetValue(const AValue: Single);
begin
 if MustBeNonnegative then
  FValue := Abs(AValue) else
  FValue := AValue;
end;

constructor TSFFloat.Create(const AName: string; const AValue: Single);
begin
  Create(AName, AValue, false);
end;

constructor TSFFloat.Create(const AName: string; const AValue: Single; AMustBeNonnegative: boolean);
begin
  inherited Create(AName);

  FMustBeNonnegative := AMustBeNonnegative;
  Value := AValue;
  DefaultValue := Value; { DefaultValue := Value, nie AValue, zeby SetValue moglo ew. zmienic Value }
  DefaultValueExists := true;
end;

procedure TSFFloat.Parse(Lexer: TVRMLLexer; IsClauseAllowed: boolean);
begin
  inherited;
  if IsClause then Exit;

  Value := ParseFloat(Lexer);
end;

procedure TSFFloat.SaveToStreamValue(Stream: TStream;
  const Indent: string; NodeNameBinding: TStringList);
begin
  WriteStr(Stream, FloatToRawStr(Value));
end;

function TSFFloat.EqualsDefaultValue: boolean;
begin
 result := (not IsClause) and DefaultValueExists and (DefaultValue = Value)
end;

function TSFFloat.Equals(SecondValue: TVRMLField;
  const EqualityEpsilon: Single): boolean;
begin
 Result := (inherited Equals(SecondValue, EqualityEpsilon)) and
   (SecondValue is TSFFloat) and
   (TSFFloat(SecondValue).MustBeNonnegative = MustBeNonnegative) and
   FloatsEqual(TSFFloat(SecondValue).Value, Value, EqualityEpsilon);
end;

procedure TSFFloat.AssignLerp(const A: Single; Value1, Value2: TSFFloat);
begin
 Value := Lerp(A, Value1.Value, Value2.Value);
end;

procedure TSFFloat.Assign(Source: TPersistent);
begin
 if Source is TSFFloat then
 begin
  DefaultValue       := TSFFloat(Source).DefaultValue;
  DefaultValueExists := TSFFloat(Source).DefaultValueExists;
  FValue             := TSFFloat(Source).Value;
  FMustBeNonnegative := TSFFloat(Source).MustBeNonnegative;
  VRMLFieldAssignCommon(TVRMLField(Source));
 end else
  inherited;
end;

class function TSFFloat.VRMLTypeName: string;
begin
  Result := 'SFFloat';
end;

{ TSFTime -------------------------------------------------------------------- }

constructor TSFTime.Create(const AName: string; const AValue: Double);
begin
  inherited Create(AName);

  Value := AValue;
  DefaultValue := Value;
  DefaultValueExists := true;
end;

procedure TSFTime.SetValue(const AValue: Double);
begin
  FValue := AValue;
end;

procedure TSFTime.Parse(Lexer: TVRMLLexer; IsClauseAllowed: boolean);
begin
  inherited;
  if IsClause then Exit;

  Value := ParseFloat(Lexer);
end;

procedure TSFTime.SaveToStreamValue(Stream: TStream;
  const Indent: string; NodeNameBinding: TStringList);
begin
  WriteStr(Stream, FloatToRawStr(Value));
end;

function TSFTime.EqualsDefaultValue: boolean;
begin
  Result := (not IsClause) and DefaultValueExists and (DefaultValue = Value);
end;

function TSFTime.Equals(SecondValue: TVRMLField;
  const EqualityEpsilon: Single): boolean;
begin
 Result := (inherited Equals(SecondValue, EqualityEpsilon)) and
   (SecondValue is TSFTime) and
   FloatsEqual(TSFTime(SecondValue).Value, Value, EqualityEpsilon);
end;

procedure TSFTime.AssignLerp(const A: Double; Value1, Value2: TSFTime);
begin
  Value := Lerp(A, Value1.Value, Value2.Value);
end;

procedure TSFTime.Assign(Source: TPersistent);
begin
  if Source is TSFTime then
  begin
    DefaultValue       := TSFTime(Source).DefaultValue;
    DefaultValueExists := TSFTime(Source).DefaultValueExists;
    FValue             := TSFTime(Source).Value;
    VRMLFieldAssignCommon(TVRMLField(Source));
  end else
    inherited;
end;

class function TSFTime.VRMLTypeName: string;
begin
  Result := 'SFTime';
end;

{ TSFImage ------------------------------------------------------------------- }

constructor TSFImage.Create(const AName: string; const AValue: TImage);
begin
  inherited Create(AName);

  if AValue <> nil then
  begin
    FreeAndNil(Value);
    Value := AValue;
  end;
end;

constructor TSFImage.CreateUndefined(const AName: string);
begin
  inherited;

  { Value must be initialized to non-nil. }
  Value := TRGBImage.Create;
end;

destructor TSFImage.Destroy;
begin
 FreeAndNil(Value);
 inherited;
end;

procedure TSFImage.Parse(Lexer: TVRMLLexer; IsClauseAllowed: boolean);

  procedure ReplaceValue(NewValue: TImage);
  begin
   FreeAndNil(Value);
   Value := NewValue;
  end;

var
  w, h, comp, pixel: LongWord;
  i: Cardinal;
  RGBPixels: PArray_Vector3Byte;
  AlphaPixels: PArray_Vector4Byte;
begin
  inherited;

  { Note that we should never let Value to be nil too long,
    because even if this method exits with exception, Value should
    always remain non-nil.
    That's why I'm doing below Value.Null instead of FreeAndNil(Value)
    and I'm using ReplaceValue to set new Value.
    This way if e.g. TRGBImage.Create with out of mem exception,
    Value will still remain non-nil.

    This is all because I just changed Images unit interface to class-like
    and I want to do minimal changes to VRMLFields unit to not break
    anything. TODO -- this will be solved better in the future, by simply
    allowing Value to be nil at any time.
    }

  Value.Null;

  if IsClause then Exit;

  { TODO: we convert here 1 and 2 components to 3 and 4 (that is,
    we convert grayscale to RGB). This is a limitation of our Images unit. }

  w := ParseLongWord(Lexer);
  h := ParseLongWord(Lexer);
  comp := ParseLongWord(Lexer);

  { If w or h =0 then w*h = 0 so we don't have to read anything more.
    We leave Value.IsNull in this case. }
  if (w <> 0) and (h <> 0) then
  begin
   case comp of
    1: begin
        ReplaceValue(TRGBImage.Create(w, h));
        RGBPixels := PArray_Vector3Byte(Value.RawPixels);
        for i := 0 to w*h-1 do
        begin
         pixel := ParseLongWord(Lexer);
         RGBPixels^[i, 0] := pixel and $FF;
         RGBPixels^[i, 1] := pixel and $FF;
         RGBPixels^[i, 2] := pixel and $FF;
        end;
       end;
    2: begin
        ReplaceValue(TAlphaImage.Create(w, h));
        AlphaPixels := PArray_Vector4Byte(Value.RawPixels);
        for i := 0 to w*h-1 do
        begin
         pixel := ParseLongWord(Lexer);
         AlphaPixels^[i, 0] := (pixel shr 8) and $FF;
         AlphaPixels^[i, 1] := (pixel shr 8) and $FF;
         AlphaPixels^[i, 2] := (pixel shr 8) and $FF;
         AlphaPixels^[i, 3] := pixel and $FF;
        end;
       end;
    3: begin
        ReplaceValue(TRGBImage.Create(w, h));
        RGBPixels := PArray_Vector3Byte(Value.RawPixels);
        for i := 0 to w*h-1 do
        begin
         pixel := ParseLongWord(Lexer);
         RGBPixels^[i, 0] := (pixel shr 16) and $FF;
         RGBPixels^[i, 1] := (pixel shr 8) and $FF;
         RGBPixels^[i, 2] := pixel and $FF;
        end;
       end;
    4: begin
        ReplaceValue(TAlphaImage.Create(w, h));
        AlphaPixels := PArray_Vector4Byte(Value.RawPixels);
        for i := 0 to w*h-1 do
        begin
         pixel := ParseLongWord(Lexer);
         AlphaPixels^[i, 0] := (pixel shr 24) and $FF;
         AlphaPixels^[i, 1] := (pixel shr 16) and $FF;
         AlphaPixels^[i, 2] := (pixel shr 8) and $FF;
         AlphaPixels^[i, 3] := pixel and $FF;
        end;
       end;
    else raise EVRMLParserError.Create(Lexer, Format('Invalid components count'+
           ' for SFImage : is %d, should be 1, 2, 3 or 4.',[comp]));
   end;
  end;
end;

procedure TSFImage.SaveToStreamValue(Stream: TStream;
  const Indent: string; NodeNameBinding: TStringList);
var rgb: TVector3Byte;
    rgba: TVector4Byte;
    i: Cardinal;
    pixel: LongWord;
begin
 if Value.IsNull then
  WriteStr(Stream, '0 0 1') else
 begin
  WriteStr(Stream, Format('%d %d %d', [Value.Width, Value.Height,
    Value.ColorComponentsCount]) +nl +Indent +IndentIncrement);
  {$I NoRQCheckBegin.inc}
  if Value is TRGBImage then
  begin
   for i := 0 to Value.Width*Value.Height-1 do
   begin
    rgb := PArray_Vector3Byte(TRGBImage(Value).RGBPixels)^[i];
    pixel := (rgb[0] shl 16) or (rgb[1] shl 8) or rgb[2];
    WriteStr(Stream, Format('0x%.6x ', [pixel]));
   end;
  end else
  if Value is TAlphaImage then
  begin
   for i := 0 to Value.Width*Value.Height-1 do
   begin
    rgba := PArray_Vector4Byte(TAlphaImage(Value).AlphaPixels)^[i];
    pixel := (rgba[0] shl 24) or (rgba[1] shl 16) or (rgba[2] shl 8) or rgba[3];
    WriteStr(Stream, Format('0x%.8x ', [pixel]));
   end;
  end else
   raise Exception.Create('TSFImage.SaveToStreamValue - not implemented TImage descendant');
  {$I NoRQCheckEnd.inc}
 end;
end;

function TSFImage.Equals(SecondValue: TVRMLField;
  const EqualityEpsilon: Single): boolean;
begin
 Result := (inherited Equals(SecondValue, EqualityEpsilon)) and
   (SecondValue is TSFImage) and
   { TODO: compare values
   (TSFImage(SecondValue).Value = Value) }true;
end;

procedure TSFImage.Assign(Source: TPersistent);
begin
 if Source is TSFImage then
 begin
  FreeAndNil(Value);
  Value := TSFImage(Source).Value.MakeCopy;
  VRMLFieldAssignCommon(TVRMLField(Source));
 end else
  inherited;
end;

class function TSFImage.VRMLTypeName: string;
begin
  Result := 'SFImage';
end;

{ TSFLong -------------------------------------------------------------------- }

procedure TSFLong.SetValue(const AValue: Longint);
begin
 if MustBeNonnegative then
  FValue := Abs(AValue) else
  FValue := AValue;
end;

constructor TSFLong.Create(const AName: string; const AValue: Longint);
begin
  Create(AName, AValue, false);
end;

constructor TSFLong.Create(const AName: string; const AValue: Longint; AMustBeNonnegative: boolean);
begin
  inherited Create(AName);

  FMustBeNonnegative := AMustBeNonnegative;
  Value := AValue;
  DefaultValue := Value; { DefaultValue := Value, nie AValue, zeby SetValue moglo ew. zmienic Value }
  DefaultValueExists := true;
end;

procedure TSFLong.Parse(Lexer: TVRMLLexer; IsClauseAllowed: boolean);
begin
  inherited;
  if IsClause then Exit;

  Lexer.CheckTokenIs(vtInteger);
  Value := Lexer.TokenInteger;
  Lexer.NextToken;
end;

procedure TSFLong.SaveToStreamValue(Stream: TStream;
  const Indent: string; NodeNameBinding: TStringList);
begin
  WriteStr(Stream, IntToStr(Value));
end;

function TSFLong.EqualsDefaultValue: boolean;
begin
 result := (not IsClause) and DefaultValueExists and (DefaultValue = Value)
end;

function TSFLong.Equals(SecondValue: TVRMLField;
  const EqualityEpsilon: Single): boolean;
begin
 { Note that this means that SFInt32 and SFLong will actually be considered
   equal. That's Ok, we want this. }
 Result := (inherited Equals(SecondValue, EqualityEpsilon)) and
   (SecondValue is TSFLong) and
   (TSFLong(SecondValue).MustBeNonnegative = MustBeNonnegative) and
   (TSFLong(SecondValue).Value = Value);
end;

procedure TSFLong.Assign(Source: TPersistent);
begin
 if Source is TSFLong then
 begin
  DefaultValue       := TSFLong(Source).DefaultValue;
  DefaultValueExists := TSFLong(Source).DefaultValueExists;
  FValue             := TSFLong(Source).Value;
  FMustBeNonnegative := TSFLong(Source).MustBeNonnegative;
  VRMLFieldAssignCommon(TVRMLField(Source));
 end else
  inherited;
end;

class function TSFLong.VRMLTypeName: string;
begin
  Result := 'SFLong';
end;

{ TSFInt32 ------------------------------------------------------------------- }

class function TSFInt32.VRMLTypeName: string;
begin
  Result := 'SFInt32';
end;

{ TSFMatrix ------------------------------------------------------------------ }

constructor TSFMatrix.Create(const AName: string; const AMatrix: TMatrix4Single);
begin
  inherited Create(AName);
  Matrix := AMatrix;
end;

procedure TSFMatrix.Parse(Lexer: TVRMLLexer; IsClauseAllowed: boolean);
var
  col: integer;
begin
  inherited;
  if IsClause then Exit;

  for col := 0 to 3 do ParseVector(Matrix[col], Lexer);
end;

procedure TSFMatrix.SaveToStreamValue(Stream: TStream;
  const Indent: string; NodeNameBinding: TStringList);
begin
 WriteStr(Stream, VectorToRawStr(Matrix[0]) +nl +
                  Indent +IndentIncrement +VectorToRawStr(Matrix[1]) +nl +
                  Indent +IndentIncrement +VectorToRawStr(Matrix[2]) +nl +
                  Indent +IndentIncrement +VectorToRawStr(Matrix[3]) );
end;

function TSFMatrix.Equals(SecondValue: TVRMLField;
  const EqualityEpsilon: Single): boolean;
begin
 Result := (inherited Equals(SecondValue, EqualityEpsilon)) and
   (SecondValue is TSFMatrix) and
   MatricesEqual(TSFMatrix(SecondValue).Matrix, Matrix, EqualityEpsilon);
end;

procedure TSFMatrix.AssignLerp(const A: Single; Value1, Value2: TSFMatrix);
begin
 Matrix[0] := VLerp(A, Value1.Matrix[0], Value2.Matrix[0]);
 Matrix[1] := VLerp(A, Value1.Matrix[1], Value2.Matrix[1]);
 Matrix[2] := VLerp(A, Value1.Matrix[2], Value2.Matrix[2]);
 Matrix[3] := VLerp(A, Value1.Matrix[3], Value2.Matrix[3]);
end;

procedure TSFMatrix.Assign(Source: TPersistent);
begin
 if Source is TSFMatrix then
 begin
  Matrix := TSFMatrix(Source).Matrix;
  VRMLFieldAssignCommon(TVRMLField(Source));
 end else
  inherited;
end;

class function TSFMatrix.VRMLTypeName: string;
begin
  Result := 'SFMatrix';
end;

{ TSFRotation ---------------------------------------------------------------- }

constructor TSFRotation.Create(const AName: string;
  const AnAxis: TVector3Single; const ARotationRad: Single);
begin
  inherited Create(AName);

  Axis := AnAxis;
  RotationRad := ARotationRad;
end;

procedure TSFRotation.Parse(Lexer: TVRMLLexer; IsClauseAllowed: boolean);
begin
  inherited;
  if IsClause then Exit;

  ParseVector(Axis, Lexer);
  RotationRad := ParseFloat(Lexer);
end;

function TSFRotation.GetValue: TVector4Single;
begin
  Move(Axis[0], Result[0], SizeOf(Single) * 3);
  Result[3] := RotationRad;
end;

procedure TSFRotation.SetValue(const AValue: TVector4Single);
begin
 Axis[0] := AValue[0];
 Axis[1] := AValue[1];
 Axis[2] := AValue[2];
 RotationRad := AValue[3];
end;

procedure TSFRotation.SaveToStreamValue(Stream: TStream;
  const Indent: string; NodeNameBinding: TStringList);
begin
  WriteStr(Stream, VectorToRawStr(Axis) +' ' +FloatToRawStr(RotationRad));
end;

function TSFRotation.RotatedPoint(const pt: TVector3Single): TVector3Single;
begin
 result := RotatePointAroundAxisRad(RotationRad, pt, Axis);
end;

function TSFRotation.Equals(SecondValue: TVRMLField;
  const EqualityEpsilon: Single): boolean;
begin
 Result := (inherited Equals(SecondValue, EqualityEpsilon)) and
   (SecondValue is TSFRotation) and
   VectorsEqual(TSFRotation(SecondValue).Axis, Axis, EqualityEpsilon) and
   FloatsEqual(TSFRotation(SecondValue).RotationRad, RotationRad, EqualityEpsilon);
end;

procedure TSFRotation.AssignLerp(const A: Single; Value1, Value2: TSFRotation);
begin
 Axis        := VLerp(A, Value1.Axis, Value2.Axis);
 RotationRad :=  Lerp(A, Value1.RotationRad, Value2.RotationRad);
end;

procedure TSFRotation.Assign(Source: TPersistent);
begin
 if Source is TSFRotation then
 begin
  Axis        := TSFRotation(Source).Axis;
  RotationRad := TSFRotation(Source).RotationRad;
  VRMLFieldAssignCommon(TVRMLField(Source));
 end else
  inherited;
end;

class function TSFRotation.VRMLTypeName: string;
begin
  Result := 'SFRotation';
end;

{ TSFString ------------------------------------------------------------------ }

constructor TSFString.Create(const AName: string; const AValue: string);
begin
  inherited Create(AName);

  Value := AValue;
  DefaultValue := Value;
  DefaultValueExists := true;
end;

procedure TSFString.Parse(Lexer: TVRMLLexer; IsClauseAllowed: boolean);
begin
  inherited;
  if IsClause then Exit;

  Lexer.CheckTokenIs(vtString);
  Value := Lexer.TokenString;
  Lexer.NextToken;
end;

procedure TSFString.SaveToStreamValue(Stream: TStream;
  const Indent: string; NodeNameBinding: TStringList);
begin
 WriteStr(Stream, StringToVRMLStringToken(Value));
end;

function TSFString.EqualsDefaultValue: boolean;
begin
 result := (not IsClause) and DefaultValueExists and (DefaultValue = Value);
end;

function TSFString.Equals(SecondValue: TVRMLField;
  const EqualityEpsilon: Single): boolean;
begin
 Result := (inherited Equals(SecondValue, EqualityEpsilon)) and
   (SecondValue is TSFString) and
   (TSFString(SecondValue).Value = Value);
end;

procedure TSFString.Assign(Source: TPersistent);
begin
 if Source is TSFString then
 begin
  DefaultValue       := TSFString(Source).DefaultValue;
  DefaultValueExists := TSFString(Source).DefaultValueExists;
  Value              := TSFString(Source).Value;
  VRMLFieldAssignCommon(TVRMLField(Source));
 end else
  inherited;
end;

class function TSFString.VRMLTypeName: string;
begin
  Result := 'SFString';
end;

{ TSFVec2f ------------------------------------------------------------------- }

constructor TSFVec2f.Create(const AName: string; const AValue: TVector2Single);
begin
  inherited Create(AName);

  Value := AValue;
  DefaultValue := Value;
  DefaultValueExists := true;
end;

procedure TSFVec2f.Parse(Lexer: TVRMLLexer; IsClauseAllowed: boolean);
begin
  inherited;
  if IsClause then Exit;

  ParseVector(Value, Lexer);
end;

procedure TSFVec2f.SaveToStreamValue(Stream: TStream;
  const Indent: string; NodeNameBinding: TStringList);
begin
  WriteStr(Stream, VectorToRawStr(Value));
end;

function TSFVec2f.EqualsDefaultValue: boolean;
begin
  result := (not IsClause) and
    DefaultValueExists and (DefaultValue[0] = Value[0])
                       and (DefaultValue[1] = Value[1]);
end;

function TSFVec2f.Equals(SecondValue: TVRMLField;
  const EqualityEpsilon: Single): boolean;
begin
 Result := (inherited Equals(SecondValue, EqualityEpsilon)) and
   (SecondValue is TSFVec2f) and
   VectorsEqual(TSFVec2f(SecondValue).Value, Value, EqualityEpsilon);
end;

procedure TSFVec2f.AssignLerp(const A: Single; Value1, Value2: TSFVec2f);
begin
 Value := VLerp(A, Value1.Value, Value2.Value);
end;

procedure TSFVec2f.Assign(Source: TPersistent);
begin
 if Source is TSFVec2f then
 begin
  DefaultValue       := TSFVec2f(Source).DefaultValue;
  DefaultValueExists := TSFVec2f(Source).DefaultValueExists;
  Value              := TSFVec2f(Source).Value;
  VRMLFieldAssignCommon(TVRMLField(Source));
 end else
  inherited;
end;

class function TSFVec2f.VRMLTypeName: string;
begin
  Result := 'SFVec2f';
end;

{ TSFVec3f ------------------------------------------------------------------- }

constructor TSFVec3f.Create(const AName: string; const AValue: TVector3Single);
begin
  inherited Create(AName);

  Value := AValue;
  DefaultValue := Value;
  DefaultValueExists := true;
end;

procedure TSFVec3f.Parse(Lexer: TVRMLLexer; IsClauseAllowed: boolean);
begin
  inherited;
  if IsClause then Exit;

  ParseVector(Value, Lexer);
end;

procedure TSFVec3f.SaveToStreamValue(Stream: TStream;
  const Indent: string; NodeNameBinding: TStringList);
begin
  WriteStr(Stream, VectorToRawStr(Value));
end;

function TSFVec3f.EqualsDefaultValue: boolean;
begin
  result := (not IsClause) and
    DefaultValueExists and (DefaultValue[0] = Value[0])
                       and (DefaultValue[1] = Value[1])
                       and (DefaultValue[2] = Value[2]);
end;

function TSFVec3f.Equals(SecondValue: TVRMLField;
  const EqualityEpsilon: Single): boolean;
begin
 Result := (inherited Equals(SecondValue, EqualityEpsilon)) and
   (SecondValue is TSFVec3f) and
   VectorsEqual(TSFVec3f(SecondValue).Value, Value, EqualityEpsilon);
end;

procedure TSFVec3f.AssignLerp(const A: Single; Value1, Value2: TSFVec3f);
begin
 Value := VLerp(A, Value1.Value, Value2.Value);
end;

procedure TSFVec3f.Assign(Source: TPersistent);
begin
 if Source is TSFVec3f then
 begin
  DefaultValue       := TSFVec3f(Source).DefaultValue;
  DefaultValueExists := TSFVec3f(Source).DefaultValueExists;
  Value              := TSFVec3f(Source).Value;
  VRMLFieldAssignCommon(TVRMLField(Source));
 end else
  inherited;
end;

class function TSFVec3f.VRMLTypeName: string;
begin
  Result := 'SFVec3f';
end;

{ TSFBitMask ------------------------------------------------------------ }

constructor TSFBitMask.Create(const AName: string; const AFlagNames: array of string;
  const ANoneString, AAllString: string; const AFlags: array of boolean);
var i: integer;
begin
  inherited Create(AName);

  fFlagNames := TStringListCaseSens.Create;
  AddStrArrayToStrings(AFlagNames, fFlagNames);
  for i := 0 to FlagsCount-1 do Flags[i] := AFlags[i];
  fNoneString := ANoneString;
  fAllString := AAllString;

  Assert(NoneString <> '', 'NoneString must be defined for SFBitMask');
end;

destructor TSFBitMask.Destroy;
begin
 fFlagNames.Free;
 inherited;
end;

function TSFBitMask.GetFlags(i: integer): boolean;
begin result := i in fFlags end;
procedure TSFBitMask.SetFlags(i: integer; value: boolean);
begin if value then Include(fFlags, i) else Exclude(fFlags, i) end;

function TSFBitMask.FlagsCount: integer;
begin result := fFlagNames.Count end;
function TSFBitMask.GetFlagNames(i: integer): string;
begin result := fFlagNames[i] end;

procedure TSFBitMask.Parse(Lexer: TVRMLLexer; IsClauseAllowed: boolean);

  procedure InterpretTokenAsFlagName;
  var i: integer;
  begin
   Lexer.CheckTokenIs(vtName, 'bit mask constant');
   i := fFlagNames.IndexOf(Lexer.TokenName);
   if i >= 0 then
    Flags[i] := true else
   if Lexer.TokenName = fAllString then
    fFlags:=[0..FlagsCount-1] else
   if Lexer.TokenName = fNoneString then
    {don't set anything; uwaga: flaga NONE nie powoduje wyczyszczenia innych flag,
    czyli np. ( FLAG_1 | NONE ) znaczy tyle samo co FLAG_1 } else
    raise EVRMLParserError.Create(Lexer,
      'Expected bit mask constant, got '+Lexer.DescribeToken);
  end;

begin
  inherited;

  fFlags:=[];

  if IsClause then Exit;

  if Lexer.Token = vtOpenBracket then
  begin
   repeat
    Lexer.NextToken;
    InterpretTokenAsFlagName;
    Lexer.NextToken;
   until Lexer.Token <> vtBar;
   Lexer.CheckTokenIs(vtCloseBracket);
   Lexer.NextToken;
  end else
  begin
   InterpretTokenAsFlagName;
   Lexer.NextToken;
  end;
end;

function TSFBitMask.AreAllFlags(value: boolean): boolean;
var i: integer;
begin
 for i := 0 to FlagsCount-1 do
  if Flags[i] <> value then exit(false);
 exit(true);
end;

procedure TSFBitMask.SaveToStreamValue(Stream: TStream;
  const Indent: string; NodeNameBinding: TStringList);
var i: integer;
    PrecedeWithBar: boolean;
begin
 if AreAllFlags(false) then
  WriteStr(Stream, NoneString) else
 begin
  {zapisywanie do strumienia AllString to taka estetyka - zawsze przeciez
   mozemy wyrazic All flags po prostu zapisujac je wszystkie. }
  if (AllString <> '') and AreAllFlags(true) then
   WriteStr(Stream, AllString) else
  begin
   PrecedeWithBar := false; { pierwszy element nie bedzie poprzedzony '|' }
   WriteStr(Stream, '(');
   for i := 0 to FlagsCount-1 do
    if Flags[i] then
    begin
     if PrecedeWithBar then WriteStr(Stream, '|') else PrecedeWithBar := true;
     WriteStr(Stream, FlagNames[i]);
    end;
   WriteStr(Stream, ')');
  end;
 end;
end;

function TSFBitMask.Equals(SecondValue: TVRMLField;
  const EqualityEpsilon: Single): boolean;
begin
 Result := (inherited Equals(SecondValue, EqualityEpsilon)) and
   (SecondValue is TSFBitMask) and
   (TSFBitMask(SecondValue).FFlagNames.Equals(FFlagNames)) and
   (TSFBitMask(SecondValue).FFlags = FFlags) and
   (TSFBitMask(SecondValue).AllString = AllString) and
   (TSFBitMask(SecondValue).NoneString = NoneString);
end;

procedure TSFBitMask.Assign(Source: TPersistent);
begin
 if Source is TSFBitMask then
 begin
  FAllString  := TSFBitMask(Source).AllString;
  FNoneString := TSFBitMask(Source).NoneString;
  FFlags      := TSFBitMask(Source).FFlags;
  FFlagNames.Assign(TSFBitMask(Source).FFlagNames);
  VRMLFieldAssignCommon(TVRMLField(Source));
 end else
  inherited;
end;

class function TSFBitMask.VRMLTypeName: string;
begin
  Result := 'SFBitMask';
end;

{ TSFEnum ----------------------------------------------------------------- }

constructor TSFEnum.Create(const AName: string; const AEnumNames: array of string; const AValue: integer);
begin
  inherited Create(AName);

  fEnumNames := TStringListCaseSens.Create;
  AddStrArrayToStrings(AEnumNames, fEnumNames);
  Value := AValue;
  DefaultValue := Value;
  DefaultValueExists := true;
end;

destructor TSFEnum.Destroy;
begin
  fEnumNames.Free;
  inherited;
end;

function TSFEnum.GetEnumNames(i: integer): string;
begin result := fEnumNames[i] end;
function TSFEnum.EnumNamesCount: integer;
begin result := fEnumNames.Count end;

procedure TSFEnum.Parse(Lexer: TVRMLLexer; IsClauseAllowed: boolean);
var
  val: integer;
begin
  inherited;
  if IsClause then Exit;

  Lexer.CheckTokenIs(vtName, 'enumerated type constant');
  val := fEnumNames.IndexOf(Lexer.TokenName);
  if val = -1 then
   raise EVRMLParserError.Create(Lexer,
     'Expected enumerated type constant, got '+Lexer.DescribeToken);
  Value := val;
  Lexer.NextToken;
end;

procedure TSFEnum.SaveToStreamValue(Stream: TStream;
  const Indent: string; NodeNameBinding: TStringList);
begin
  WriteStr(Stream, EnumNames[Value]);
end;

function TSFEnum.EqualsDefaultValue: boolean;
begin
 result := (not IsClause) and DefaultValueExists and (DefaultValue = Value);
end;

function TSFEnum.Equals(SecondValue: TVRMLField;
  const EqualityEpsilon: Single): boolean;
begin
 Result := (inherited Equals(SecondValue, EqualityEpsilon)) and
   (SecondValue is TSFEnum) and
   (TSFEnum(SecondValue).FEnumNames.Equals(FEnumNames)) and
   (TSFEnum(SecondValue).Value = Value);
end;

procedure TSFEnum.Assign(Source: TPersistent);
begin
 if Source is TSFEnum then
 begin
  DefaultValue       := TSFEnum(Source).DefaultValue;
  DefaultValueExists := TSFEnum(Source).DefaultValueExists;
  Value              := TSFEnum(Source).Value;
  FEnumNames.Assign(TSFEnum(Source).FEnumNames);
  VRMLFieldAssignCommon(TVRMLField(Source));
 end else
  inherited;
end;

class function TSFEnum.VRMLTypeName: string;
begin
  Result := 'SFEnum';
end;

{ multiple value fields ----------------------------------------------------- }

{ Note that because of FPC 2.0.2 bug, code below will not compile
  with FPC 2.0.2 in objfpc mode. For objfpc mode I would have to
  change below Items.Items[I] to Items.ItemsArray^[I],
  i.e. Items property of my dynamic array classes will not work
  correctly in objfpc mode in FPC 2.0.2.
  Fixed in FPC 2.0.3 and 2.1.1 (revision 2911).
}

{$ifdef FPC_OBJFPC}
  {$ifdef VER2_0_2}
    {$fatal This code will not compile with FPC 2.0.2 in objfpc mode}
  {$endif}
{$endif}

{$define IMPLEMENT_MF_CLASS:=
constructor TMF_CLASS.Create(const AName: string;
  const InitialContent: array of TMF_STATIC_ITEM);
begin
  inherited Create(AName);

  Items.AppendArray(InitialContent);

  (* inicjuj DefaultValuesCount, inicjuj tez DefaultValue
     jesli DefaultValuesCount = 1 *)
  case High(InitialContent) + 1 of
    0: DefaultValuesCount := 0;
    1: begin
         DefaultValuesCount := 1;
         DefaultValue := InitialContent[0];
       end;
    else DefaultValuesCount := -1;
  end;
end;

constructor TMF_CLASS.CreateUndefined(const AName: string);
begin
  inherited;

  FItemClass := TMF_CLASS_ITEM;
  RawItems := TMF_DYN_STATIC_ITEM_ARRAY.Create;
  DefaultValuesCount := -1;
end;

function TMF_CLASS.Items: TMF_DYN_STATIC_ITEM_ARRAY;
begin result := TMF_DYN_STATIC_ITEM_ARRAY(RawItems) end;

procedure TMF_CLASS.RawItemsAdd(Item: TVRMLSingleField);
begin
 Items.AppendItem(TMF_CLASS_ITEM(Item).Value);
end;

procedure TMF_CLASS.Assign(Source: TPersistent);
begin
 if Source is TMF_CLASS then
 begin
  DefaultValuesCount := TMF_CLASS(Source).DefaultValuesCount;
  DefaultValue       := TMF_CLASS(Source).DefaultValue;
  Items.Assign(TMF_CLASS(Source).Items);
  VRMLFieldAssignCommon(TVRMLField(Source));
 end else
  inherited;
end;
}

{ dla niektorych klas MF nie bedzie mialo znaczenia ktorej wersji
  IMPLEMENT_MF_CLASS_EQUALS_DEFAULT_VALUE_USING_* uzyjemy.

  Ale dla niektorych typow TMF_STATIC_ITEM operator "=" moze nie byc
  standardowo dostepny (i calkiem slusznie, bo dla tych typow nie zawsze
  chcielibysmy robic dokladne porownanie; TERAZ jednak wlasnie tego chcemy).
  Np. dla typow TVector2/3Single. Dlatego musimy wtedy uzywac metody
  CompareMem. Ale metoda CompareMem tez nie jest zawsze dobra - dla
  stringow na przyklad ta metoda jest bez sensu. Ale dla stringow metoda
  z operatorem "=" ma sens.

  W tej chwili nie ma klasy MF ktora wymagalaby jakiegos jeszcze innego
  traktowania ale niektrudno sobie taka wyobrazic. Nie wszystkie
  typy mozemy przeciez sensownie porownywac operatorem "=" lub CompareMem,
  np. gdybysmy mieli TMFImage.

  Notka: dla klas dla ktorych obie wersje (CompareMem i "=") sa dobre
  uzywam wersji "=" (bo jest bezpieczniejsza na typach).
}

{$define IMPLEMENT_MF_CLASS_USING_EQUALITY_OP:=
function TMF_CLASS.EqualsDefaultValue: boolean;
begin
  result := (not IsClause) and
    ((DefaultValuesCount = 0) and (Count = 0)) or
    ((DefaultValuesCount = 1) and (Count = 1) and
     (DefaultValue = Items.Items[0]));
end;

function TMF_CLASS.Equals(SecondValue: TVRMLField;
  const EqualityEpsilon: Single): boolean;
var
  I: Integer;
begin
 Result := (inherited Equals(SecondValue, EqualityEpsilon)) and
   (SecondValue is TMF_CLASS);

 if Result then
  for I := 0 to Items.Count - 1 do
   if not (TMF_CLASS(SecondValue).Items.Items[I] = Items.Items[I]) then
    Exit(false);
end;
}

{$define IMPLEMENT_MF_CLASS_USING_COMPARE_MEM:=
function TMF_CLASS.EqualsDefaultValue: boolean;
begin
  result:= (not IsClause) and
    ((DefaultValuesCount = 0) and (Count = 0)) or
    ((DefaultValuesCount = 1) and (Count = 1) and
      CompareMem(@DefaultValue, Items.Pointers[0], SizeOf(TMF_STATIC_ITEM)) );
end;

function TMF_CLASS.Equals(SecondValue: TVRMLField;
  const EqualityEpsilon: Single): boolean;
var
  I: Integer;
begin
 Result := (inherited Equals(SecondValue, EqualityEpsilon)) and
   (SecondValue is TMF_CLASS);

 if Result then
  for I := 0 to Items.Count - 1 do
   if not CompareMem(@TMF_CLASS(SecondValue).Items.Items[I], @Items.Items[I],
     SizeOf(TMF_STATIC_ITEM)) then
    Exit(false);
end;
}

{$define IMPLEMENT_MF_CLASS_USING_VECTORS:=
function TMF_CLASS.EqualsDefaultValue: boolean;
begin
  result := (not IsClause) and
    ((DefaultValuesCount = 0) and (Count = 0)) or
    ((DefaultValuesCount = 1) and (Count = 1) and
      VectorsPerfectlyEqual(DefaultValue, Items.Items[0]) );
end;

function TMF_CLASS.Equals(SecondValue: TVRMLField;
  const EqualityEpsilon: Single): boolean;
var
  I: Integer;
begin
 Result := (inherited Equals(SecondValue, EqualityEpsilon)) and
   (SecondValue is TMF_CLASS);

 if Result then
  for I := 0 to Items.Count - 1 do
   if not VectorsEqual(TMF_CLASS(SecondValue).Items.Items[I], Items.Items[I],
     EqualityEpsilon) then
    Exit(false);
end;
}

{$define IMPLEMENT_MF_CLASS_USING_FLOATS_EQUAL:=
function TMF_CLASS.EqualsDefaultValue: boolean;
begin
  result := (not IsClause) and
    ((DefaultValuesCount = 0) and (Count = 0)) or
    ((DefaultValuesCount = 1) and (Count = 1) and
     (DefaultValue = Items.Items[0]) );
end;

function TMF_CLASS.Equals(SecondValue: TVRMLField;
  const EqualityEpsilon: Single): boolean;
var
  I: Integer;
begin
 Result := (inherited Equals(SecondValue, EqualityEpsilon)) and
   (SecondValue is TMF_CLASS);

 if Result then
  for I := 0 to Items.Count - 1 do
   if not FloatsEqual(TMF_CLASS(SecondValue).Items.Items[I], Items.Items[I],
     EqualityEpsilon) then
    Exit(false);
end;
}

{$define TMF_CLASS := TMFColor}
{$define TMF_STATIC_ITEM := TVector3Single}
{$define TMF_CLASS_ITEM := TSFColor}
{$define TMF_DYN_STATIC_ITEM_ARRAY := TDynVector3SingleArray}
IMPLEMENT_MF_CLASS
IMPLEMENT_MF_CLASS_USING_VECTORS

{$define TMF_CLASS := TMFLong}
{$define TMF_STATIC_ITEM := Longint}
{$define TMF_CLASS_ITEM := TSFLong}
{$define TMF_DYN_STATIC_ITEM_ARRAY := TDynLongintArray}
IMPLEMENT_MF_CLASS
IMPLEMENT_MF_CLASS_USING_EQUALITY_OP

{$define TMF_CLASS := TMFVec2f}
{$define TMF_STATIC_ITEM := TVector2Single}
{$define TMF_CLASS_ITEM := TSFVec2f}
{$define TMF_DYN_STATIC_ITEM_ARRAY := TDynVector2SingleArray}
IMPLEMENT_MF_CLASS
IMPLEMENT_MF_CLASS_USING_VECTORS

{$define TMF_CLASS := TMFVec3f}
{$define TMF_STATIC_ITEM := TVector3Single}
{$define TMF_CLASS_ITEM := TSFVec3f}
{$define TMF_DYN_STATIC_ITEM_ARRAY := TDynVector3SingleArray}
IMPLEMENT_MF_CLASS
IMPLEMENT_MF_CLASS_USING_VECTORS

{$define TMF_CLASS := TMFRotation}
{$define TMF_STATIC_ITEM := TVector4Single}
{$define TMF_CLASS_ITEM := TSFRotation}
{$define TMF_DYN_STATIC_ITEM_ARRAY := TDynVector4SingleArray}
IMPLEMENT_MF_CLASS
IMPLEMENT_MF_CLASS_USING_VECTORS

{$define TMF_CLASS := TMFFloat}
{$define TMF_STATIC_ITEM := Single}
{$define TMF_CLASS_ITEM := TSFFloat}
{$define TMF_DYN_STATIC_ITEM_ARRAY := TDynSingleArray}
IMPLEMENT_MF_CLASS
IMPLEMENT_MF_CLASS_USING_FLOATS_EQUAL

{$define TMF_CLASS := TMFTime}
{$define TMF_STATIC_ITEM := Double}
{$define TMF_CLASS_ITEM := TSFTime}
{$define TMF_DYN_STATIC_ITEM_ARRAY := TDynDoubleArray}
IMPLEMENT_MF_CLASS
IMPLEMENT_MF_CLASS_USING_FLOATS_EQUAL

{$define TMF_CLASS := TMFString}
{$define TMF_STATIC_ITEM := string}
{$define TMF_CLASS_ITEM := TSFString}
{$define TMF_DYN_STATIC_ITEM_ARRAY := TDynStringArray}
IMPLEMENT_MF_CLASS
IMPLEMENT_MF_CLASS_USING_EQUALITY_OP

{ TMFColor ------------------------------------------------------------------- }

function TMFColor.RawItemToString(ItemNum: integer): string;
begin result := VectorToRawStr(Items.Items[ItemNum]) end;

procedure TMFColor.AssignLerp(const A: Single; Value1, Value2: TMFColor);
var
  I: Integer;
begin
 Value1.CheckCountEqual(Value2);
 Items.Count := Value1.Items.Count;

 for I := 0 to Items.Count - 1 do
  Items.Items[I] := VLerp(A, Value1.Items.Items[I], Value2.Items.Items[I]);
end;

class function TMFColor.VRMLTypeName: string;
begin
  Result := 'MFColor';
end;

{ TMFLong -------------------------------------------------------------------- }

constructor TMFLong.CreateMFLong(const AName: string; const InitialContent: array of Longint;
 const ASaveToStreamLineUptoNegative: boolean);
begin
  Create(AName, InitialContent);
  SaveToStreamLineUptoNegative := ASaveToStreamLineUptoNegative;
end;

function TMFLong.SaveToStreamDoNewLineAfterRawItem(ItemNum: integer): boolean;
begin
 if SaveToStreamLineUptoNegative then
  result := Items.Items[ItemNum] < 0 else
  result := inherited;
end;

function TMFLong.RawItemToString(ItemNum: integer): string;
begin result := IntToStr(Items.Items[ItemNum]) end;

class function TMFLong.VRMLTypeName: string;
begin
  Result := 'MFLong';
end;

{ TMFInt32 ------------------------------------------------------------------- }

class function TMFInt32.VRMLTypeName: string;
begin
  Result := 'MFInt32';
end;

{ TMFVec2f ------------------------------------------------------------------- }

function TMFVec2f.RawItemToString(ItemNum: integer): string;
begin result := VectorToRawStr(Items.Items[ItemNum]) end;

procedure TMFVec2f.AssignLerp(const A: Single; Value1, Value2: TMFVec2f);
var
  I: Integer;
begin
 Value1.CheckCountEqual(Value2);
 Items.Count := Value1.Items.Count;

 for I := 0 to Items.Count - 1 do
  Items.Items[I] := VLerp(A, Value1.Items.Items[I], Value2.Items.Items[I]);
end;

class function TMFVec2f.VRMLTypeName: string;
begin
  Result := 'MFVec2f';
end;

{ TMFVec3f ------------------------------------------------------------------- }

function TMFVec3f.RawItemToString(ItemNum: integer): string;
begin result := VectorToRawStr(Items.Items[ItemNum]) end;

procedure TMFVec3f.AssignLerp(const A: Single; Value1, Value2: TMFVec3f);
var
  I: Integer;
begin
 Value1.CheckCountEqual(Value2);
 Items.Count := Value1.Items.Count;

 for I := 0 to Items.Count - 1 do
  Items.Items[I] := VLerp(A, Value1.Items.Items[I], Value2.Items.Items[I]);
end;

class function TMFVec3f.VRMLTypeName: string;
begin
  Result := 'MFVec3f';
end;

{ TMFRotation ---------------------------------------------------------------- }

function TMFRotation.RawItemToString(ItemNum: Integer): string;
begin
  Result := VectorToRawStr(Items.Items[ItemNum])
end;

procedure TMFRotation.AssignLerp(const A: Single; Value1, Value2: TMFRotation);
var
  I: Integer;
begin
 Value1.CheckCountEqual(Value2);
 Items.Count := Value1.Items.Count;

 for I := 0 to Items.Count - 1 do
  Items.Items[I] := VLerp(A, Value1.Items.Items[I], Value2.Items.Items[I]);
end;

class function TMFRotation.VRMLTypeName: string;
begin
  Result := 'MFRotation';
end;

{ TMFFloat ------------------------------------------------------------------- }

function TMFFloat.RawItemToString(ItemNum: integer): string;
begin result := FloatToRawStr(Items.Items[ItemNum]) end;

procedure TMFFloat.AssignLerp(const A: Single; Value1, Value2: TMFFloat);
var
  I: Integer;
begin
 Value1.CheckCountEqual(Value2);
 Items.Count := Value1.Items.Count;

 for I := 0 to Items.Count - 1 do
  Items.Items[I] := Lerp(A, Value1.Items.Items[I], Value2.Items.Items[I]);
end;

class function TMFFloat.VRMLTypeName: string;
begin
  Result := 'MFFloat';
end;

{ TMFTime -------------------------------------------------------------------- }

function TMFTime.RawItemToString(ItemNum: integer): string;
begin result := FloatToRawStr(Items.Items[ItemNum]) end;

procedure TMFTime.AssignLerp(const A: Double; Value1, Value2: TMFTime);
var
  I: Integer;
begin
 Value1.CheckCountEqual(Value2);
 Items.Count := Value1.Items.Count;

 for I := 0 to Items.Count - 1 do
  Items.Items[I] := Lerp(A, Value1.Items.Items[I], Value2.Items.Items[I]);
end;

class function TMFTime.VRMLTypeName: string;
begin
  Result := 'MFTime';
end;

{ TMFString ------------------------------------------------------------------ }

function TMFString.RawItemToString(ItemNum: integer): string;
begin result := StringToVRMLStringToken(Items.Items[ItemNum]) end;

class function TMFString.VRMLTypeName: string;
begin
  Result := 'MFString';
end;

{ TVRMLFieldsManager --------------------------------------------------------- }

constructor TVRMLFieldsManager.Create;
begin
  inherited;
  Registered := TStringList.Create;
  { All VRML names are case-sensitive. }
  Registered.CaseSensitive := true;
end;

destructor TVRMLFieldsManager.Destroy;
begin
  FreeAndNil(Registered);
  inherited;
end;

procedure TVRMLFieldsManager.RegisterClass(AClass: TVRMLFieldClass);
begin
  Registered.AddObject(AClass.VRMLTypeName, TObject(AClass));
end;

procedure TVRMLFieldsManager.RegisterClasses(
  const Classes: array of TVRMLFieldClass);
var
  I: Integer;
begin
  for I := 0 to High(Classes) do
    RegisterClass(Classes[I]);
end;

function TVRMLFieldsManager.FieldTypeNameToClass(
  const TypeName: string): TVRMLFieldClass;
var
  I: Integer;
begin
  I := Registered.IndexOf(TypeName);
  if I <> -1 then
    Result := TVRMLFieldClass(Registered.Objects[I]) else
    Result := nil;
end;

initialization
  VRMLFieldsManager := TVRMLFieldsManager.Create;

  VRMLFieldsManager.RegisterClasses([
    TSFBitMask,
    TSFEnum,
    TSFBool,
    TSFColor,
    TSFFloat,
    TSFImage,
    TSFLong,
    TSFInt32,
    TSFMatrix,
    TSFRotation,
    TSFString,
    TSFTime,
    TSFVec2f,
    TSFVec3f,
    TMFColor,
    TMFFloat,
    TMFLong,
    TMFInt32,
    TMFRotation,
    TMFString,
    TMFTime,
    TMFVec2f,
    TMFVec3f]);

finalization
  FreeAndNil(VRMLFieldsManager);
end.
