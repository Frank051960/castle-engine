{
  Copyright 2014-2014 Michalis Kamburelis.

  This file is part of "Castle Game Engine".

  "Castle Game Engine" is free software; see the file COPYING.txt,
  included in this distribution, for details about the copyright.

  "Castle Game Engine" is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

  ----------------------------------------------------------------------------
}

{ Android project componets and their configurations. }
unit ToolAndroidComponents;

interface

uses FGL, DOM,
  CastleUtils, CastleStringUtils;

type
  TAndroidComponent = class
  private
    FParameters: TStringStringMap;
    FName: string;
  public
    constructor Create;
    destructor Destroy; override;
    procedure ReadCastleEngineManifest(const Element: TDOMElement);
    property Name: string read FName;
  end;

  TAndroidComponentList = class(specialize TFPGObjectList<TAndroidComponent>)
  public
    procedure ReadCastleEngineManifest(const Element: TDOMElement);
  end;

procedure MergeAndroidManifest(const Source, Destination: string);
procedure MergeAndroidMk(const Source, Destination: string);
procedure MergeAndroidProjectProperties(const Source, Destination: string);
procedure MergeAndroidMainActivity(const Source, Destination: string);

implementation

uses SysUtils, XMLRead, XMLWrite,
  CastleXMLUtils, CastleURIUtils,
  ToolUtils;

{ TAndroidComponent ---------------------------------------------------------- }

constructor TAndroidComponent.Create;
begin
  inherited;
  FParameters := TStringStringMap.Create;
end;

destructor TAndroidComponent.Destroy;
begin
  FreeAndNil(FParameters);
  inherited;
end;

procedure TAndroidComponent.ReadCastleEngineManifest(const Element: TDOMElement);
var
  ChildElements: TDOMNodeList;
  ParametersElement, ChildElement: TDOMElement;
  I: Integer;
begin
  FName := Element.AttributeString('name');

  ParametersElement := DOMGetChildElement(Element, 'parameters', false);
  if ParametersElement <> nil then
  begin
    ChildElements := Element.GetElementsByTagName('parameter');
    for I := 0 to ChildElements.Count - 1 do
    begin
      ChildElement := ChildElements[I] as TDOMElement;
      FParameters.Add(
        ChildElement.AttributeString('key'),
        ChildElement.AttributeString('value'));
    end;
  end;
end;

{ TAndroidComponentList ------------------------------------------------------ }

procedure TAndroidComponentList.ReadCastleEngineManifest(const Element: TDOMElement);
var
  ChildElements: TDOMNodeList;
  ChildElement: TDOMElement;
  I: Integer;
  Component: TAndroidComponent;
begin
  ChildElements := Element.GetElementsByTagName('component');
  for I := 0 to ChildElements.Count - 1 do
  begin
    ChildElement := ChildElements[I] as TDOMElement;

    Component := TAndroidComponent.Create;
    Add(Component);
    Component.ReadCastleEngineManifest(ChildElement);
  end;
end;

{ globals -------------------------------------------------------------------- }

procedure MergeAndroidManifest(const Source, Destination: string);
var
  SourceXml, DestinationXml: TXMLDocument;

  procedure MergeApplication(const SourceApplication: TDOMElement);
  var
    DestinationApplication: TDOMElement;
    SourceNodes: TDOMNodeList;
    SourceAttribs: TDOMNamedNodeMap;
    I: Integer;
  begin
    DestinationApplication := DOMGetChildElement(DestinationXml.DocumentElement,
      'application', true);

    // GetChildNodes includes child comments, elements, everything... except attributes
    SourceNodes := SourceApplication.GetChildNodes;
    for I := 0 to SourceNodes.Count - 1 do
    begin
      if Verbose then
        Writeln('Appending node ', SourceNodes[I].NodeName, ' of type ', SourceNodes[I].NodeType);
      DestinationApplication.AppendChild(
        SourceNodes[I].CloneNode(true, DestinationXml));
    end;

    SourceAttribs := SourceApplication.Attributes;
    for I := 0 to SourceAttribs.Length - 1 do
    begin
      if SourceAttribs[I].NodeType <> ATTRIBUTE_NODE then
        raise Exception.Create('Attribute node does not have NodeType = ATTRIBUTE_NODE: ' +
          SourceAttribs[I].NodeName);
      if Verbose then
        Writeln('Appending attribute ', SourceAttribs[I].NodeName);
      DestinationApplication.SetAttribute(
        SourceAttribs[I].NodeName, SourceAttribs[I].NodeValue);
    end;
  end;

  procedure MergeUsesPermission(const SourceUsesPermission: TDOMElement);
  var
    SourceName: string;
    I: TXMLElementIterator;
  begin
    SourceName := SourceUsesPermission.AttributeString('android:name');

    I := TXMLElementIterator.Create(DestinationXml.DocumentElement);
    try
      while I.GetNext do
      begin
        if (I.Current.TagName = 'uses-permission') and
           I.Current.HasAttribute('android:name') and
           (I.Current.AttributeString('android:name') = SourceName) then
        begin
          if Verbose then
            Writeln('Main AndroidManifest.xml already uses-permission with ' + SourceName);
          Exit;
        end;
      end;
    finally FreeAndNil(I) end;

    DestinationXml.DocumentElement.AppendChild(
      SourceUsesPermission.CloneNode(true, DestinationXml));
  end;

var
  I: TXMLElementIterator;
begin
  if Verbose then
    Writeln('Merging "', Source, '" into "', Destination, '"');

  try
    ReadXMLFile(SourceXml, Source); // this nils SourceXml in case of error
    try
      ReadXMLFile(DestinationXml, Destination); // this nils DestinationXml in case of error

      I := TXMLElementIterator.Create(SourceXml.DocumentElement);
      try
        while I.GetNext do
        begin
          if I.Current.TagName = 'application' then
            MergeApplication(I.Current) else
          if (I.Current.TagName = 'uses-permission') and
             I.Current.HasAttribute('android:name') then
            MergeUsesPermission(I.Current) else
            raise Exception.Create('Cannot merge AndroidManifest.xml element <' + I.Current.TagName + '>');
        end;
      finally FreeAndNil(I) end;

      WriteXMLFile(DestinationXml, Destination);
    finally FreeAndNil(DestinationXml) end;
  finally FreeAndNil(SourceXml) end;
end;

procedure MergeAppend(const Source, Destination: string);
var
  SourceContents, DestinationContents: string;
begin
  if Verbose then
    Writeln('Merging "', Source, '" into "', Destination, '"');

  SourceContents := FileToString(FilenameToURISafe(Source));
  DestinationContents := FileToString(FilenameToURISafe(Destination));
  DestinationContents := DestinationContents + NL + SourceContents;
  StringToFile(Destination, DestinationContents);
end;

procedure MergeAndroidMk(const Source, Destination: string);
begin
  MergeAppend(Source, Destination);
end;

procedure MergeAndroidProjectProperties(const Source, Destination: string);
begin
  MergeAppend(Source, Destination);
end;

procedure MergeAndroidMainActivity(const Source, Destination: string);
const
  InsertMarker = '/* ANDROID-COMPONENTS-INITIALIZATION */';
var
  SourceContents, DestinationContents: string;
  MarkerPos: Integer;
begin
  if Verbose then
    Writeln('Merging "', Source, '" into "', Destination, '"');

  SourceContents := FileToString(FilenameToURISafe(Source));
  DestinationContents := FileToString(FilenameToURISafe(Destination));
  MarkerPos := Pos(InsertMarker, DestinationContents);
  if MarkerPos = 0 then
    raise Exception.CreateFmt('Cannot find marker "%s" in MainActivity.java', [InsertMarker]);
  Insert(SourceContents, DestinationContents, MarkerPos);
  StringToFile(Destination, DestinationContents);
end;

end.
