{ -*- buffer-read-only: t -*-

  Copyright 2015-2017 Michalis Kamburelis.

  This file is part of "Castle Game Engine".

  "Castle Game Engine" is free software; see the file COPYING.txt,
  included in this distribution, for details about the copyright.

  "Castle Game Engine" is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

  ----------------------------------------------------------------------------
}

{ Automatically generated node properties.

  Do not edit this file manually!
  To add new properties, add them to text files in nodes_specification/components/ ,
  and regenerate include files by running
  nodes_specification/generate_x3d_nodes_to_pascal.lpr .

  The documentation for properties should go to x3dnodes_documentation.txt . }

{$ifdef read_interface}

  private
    function GetAxisRotation: TVector4Single;
    procedure SetAxisRotation(const Value: TVector4Single);
    function GetDiskAngle: Single;
    procedure SetDiskAngle(const Value: Single);
    function GetMaxAngle: Single;
    procedure SetMaxAngle(const Value: Single);
    function GetMinAngle: Single;
    procedure SetMinAngle(const Value: Single);
    function GetOffset: Single;
    procedure SetOffset(const Value: Single);
  public
    property AxisRotation: TVector4Single read GetAxisRotation write SetAxisRotation;
    property DiskAngle: Single read GetDiskAngle write SetDiskAngle;
    property MaxAngle: Single read GetMaxAngle write SetMaxAngle;
    property MinAngle: Single read GetMinAngle write SetMinAngle;
    property Offset: Single read GetOffset write SetOffset;

{$endif read_interface}

{$ifdef read_implementation}

{ TCylinderSensorNode ----------------------------------------------- }

function TCylinderSensorNode.GetAxisRotation: TVector4Single;
begin
  Result := FdAxisRotation.Value;
end;

procedure TCylinderSensorNode.SetAxisRotation(const Value: TVector4Single);
begin
  FdAxisRotation.Send(Value);
end;

function TCylinderSensorNode.GetDiskAngle: Single;
begin
  Result := FdDiskAngle.Value;
end;

procedure TCylinderSensorNode.SetDiskAngle(const Value: Single);
begin
  FdDiskAngle.Send(Value);
end;

function TCylinderSensorNode.GetMaxAngle: Single;
begin
  Result := FdMaxAngle.Value;
end;

procedure TCylinderSensorNode.SetMaxAngle(const Value: Single);
begin
  FdMaxAngle.Send(Value);
end;

function TCylinderSensorNode.GetMinAngle: Single;
begin
  Result := FdMinAngle.Value;
end;

procedure TCylinderSensorNode.SetMinAngle(const Value: Single);
begin
  FdMinAngle.Send(Value);
end;

function TCylinderSensorNode.GetOffset: Single;
begin
  Result := FdOffset.Value;
end;

procedure TCylinderSensorNode.SetOffset(const Value: Single);
begin
  FdOffset.Send(Value);
end;

{$endif read_implementation}