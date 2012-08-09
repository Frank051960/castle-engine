{
  Copyright 2008-2012 Michalis Kamburelis.

  This file is part of "Castle Game Engine".

  "Castle Game Engine" is free software; see the file COPYING.txt,
  included in this distribution, for details about the copyright.

  "Castle Game Engine" is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

  ----------------------------------------------------------------------------
}

{ Utilities for cooperation between LCL and "Castle Game Engine". }
unit CastleLCLUtils;

interface

uses FileFilters, Dialogs;

{ Convert file filters into LCL Dialog.Filter, Dialog.FilterIndex.
  Suitable for both open and save dialogs (TOpenDialog, TSaveDialog
  both descend from TFileDialog).

  Input filters are either given as a string FileFilters
  (encoded just like for TFileFilterList.AddFiltersFromString),
  or as TFileFilterList instance.

  Output filters are either written to LCLFilter, LCLFilterIndex
  variables, or set appropriate properties of given Dialog instance.

  When AllFields is false, then filters starting with "All " in the name,
  like "All files", "All images", are not included in the output.

  @groupBegin }
procedure FileFiltersToDialog(const FileFilters: string;
  Dialog: TFileDialog; const AllFields: boolean = true);
procedure FileFiltersToDialog(const FileFilters: string;
  out LCLFilter: string; out LCLFilterIndex: Integer; const AllFields: boolean = true);
procedure FileFiltersToDialog(FFList: TFileFilterList;
  Dialog: TFileDialog; const AllFields: boolean = true);
procedure FileFiltersToDialog(FFList: TFileFilterList;
  out LCLFilter: string; out LCLFilterIndex: Integer; const AllFields: boolean = true);
{ @groupEnd }

{ Make each '&' inside string '&&', this way the string will not contain
  special '&x' sequences when used as a TMenuItem.Caption and such. }
function SQuoteLCLCaption(const S: string): string;

{ Deprecated names, use the identifiers without "Open" in new code.
  @deprecated
  @groupBegin }
procedure FileFiltersToOpenDialog(const FileFilters: string;
  Dialog: TFileDialog); deprecated;
procedure FileFiltersToOpenDialog(const FileFilters: string;
  out LCLFilter: string; out LCLFilterIndex: Integer); deprecated;
procedure FileFiltersToOpenDialog(FFList: TFileFilterList;
  out LCLFilter: string; out LCLFilterIndex: Integer); deprecated;
{ @groupEnd }

implementation

uses SysUtils, CastleClassUtils, CastleStringUtils;

procedure FileFiltersToDialog(const FileFilters: string;
  Dialog: TFileDialog; const AllFields: boolean);
var
  LCLFilter: string;
  LCLFilterIndex: Integer;
begin
  FileFiltersToDialog(FileFilters, LCLFilter, LCLFilterIndex, AllFields);
  Dialog.Filter := LCLFilter;
  Dialog.FilterIndex := LCLFilterIndex;
end;

procedure FileFiltersToDialog(const FileFilters: string;
  out LCLFilter: string; out LCLFilterIndex: Integer; const AllFields: boolean);
var
  FFList: TFileFilterList;
begin
  FFList := TFileFilterList.Create(true);
  try
    FFList.AddFiltersFromString(FileFilters);
    FileFiltersToDialog(FFList, LCLFilter, LCLFilterIndex, AllFields);
  finally FreeAndNil(FFList) end;
end;

procedure FileFiltersToDialog(FFList: TFileFilterList;
  Dialog: TFileDialog; const AllFields: boolean);
var
  LCLFilter: string;
  LCLFilterIndex: Integer;
begin
  FileFiltersToDialog(FFList, LCLFilter, LCLFilterIndex, AllFields);
  Dialog.Filter := LCLFilter;
  Dialog.FilterIndex := LCLFilterIndex;
end;

procedure FileFiltersToDialog(FFList: TFileFilterList;
  out LCLFilter: string; out LCLFilterIndex: Integer; const AllFields: boolean);
var
  Filter: TFileFilter;
  I, J: Integer;
begin
  LCLFilter := '';

  { initialize LCLFilterIndex.
    Will be corrected for AllFields=false case, and will be incremented
    (because LCL FilterIndex counts from 1) later. }

  LCLFilterIndex := FFList.DefaultFilter;

  for I := 0 to FFList.Count - 1 do
  begin
    Filter := FFList[I];
    if (not AllFields) and IsPrefix('All ', Filter.Name) then
    begin
      { then we don't want to add this to LCLFilter.
        We also need to fix LCLFilterIndex, to shift it. }
      if I = FFList.DefaultFilter then
        LCLFilterIndex := 0 else
      if I < FFList.DefaultFilter then
        Dec(LCLFilterIndex);
      Continue;
    end;

    LCLFilter += Filter.Name + '|';

    for J := 0 to Filter.Patterns.Count - 1 do
    begin
      if J <> 0 then LCLFilter += ';';
      LCLFilter += Filter.Patterns[J];
    end;

    LCLFilter += '|';
  end;

  { LCL FilterIndex counts from 1. }
  Inc(LCLFilterIndex);
end;

function SQuoteLCLCaption(const S: string): string;
begin
  Result := StringReplace(S, '&', '&&', [rfReplaceAll]);
end;

{ Deprecated functions, just call identifier without "Open". }

procedure FileFiltersToOpenDialog(const FileFilters: string;
  Dialog: TFileDialog);
begin
  FileFiltersToDialog(FileFilters, Dialog);
end;

procedure FileFiltersToOpenDialog(const FileFilters: string;
  out LCLFilter: string; out LCLFilterIndex: Integer);
begin
  FileFiltersToDialog(FileFilters, LCLFilter, LCLFilterIndex);
end;

procedure FileFiltersToOpenDialog(FFList: TFileFilterList;
  out LCLFilter: string; out LCLFilterIndex: Integer);
begin
  FileFiltersToDialog(FFList, LCLFilter, LCLFilterIndex);
end;

end.
