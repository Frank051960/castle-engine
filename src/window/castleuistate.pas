{
  Copyright 2015-2015 Michalis Kamburelis.

  This file is part of "Castle Game Engine".

  "Castle Game Engine" is free software; see the file COPYING.txt,
  included in this distribution, for details about the copyright.

  "Castle Game Engine" is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

  ----------------------------------------------------------------------------
}

{ UI state (TUIState). }
unit CastleUIState;

interface

uses Classes, FGL,
  CastleConfig, CastleKeysMouse, CastleImages, CastleUIControls,
  CastleGLImages, CastleVectors;

type
  { UI state, a useful singleton to manage the state of your game UI.

    Only one state is @italic(current) at a given time, it can
    be get or set using the TUIState.Current property.
    (Unless you use TUIState.Push, in which case you build a stack
    of states, all of them are available at the same time.)

    Each state has comfortable @link(Start) and @link(Finish)
    methods that you can override to perform work when state becomes
    current, or stops being current. Most importantly, you can
    add/remove additional state-specific UI controls in @link(Start) and @link(Finish)
    methods. Add them in @link(Start) method like
    @code(StateContainer.Controls.InsertFront(...)), remove them by
    @code(StateContainer.Controls.Remove(...)).

    Current state is also placed on the list of container controls.
    (Always @italic(under) state-specific UI controls you added
    to container in @link(Start) method.) This way state is notified
    about UI events, and can react to them. In case of events that
    can be "handled" (like TUIControl.Press, TUIControl.Release events)
    the state is notified about them only if no other state-specific
    UI control handled them.

    This way state can

    @unorderedList(
      @item(catch press/release and similar events, when no other
        state-specific control handled them,)
      @item(catch update, GL context open/close and other useful events,)
      @item(can have it's own render function, to directly draw UI.)
    )

    See the TUIControl class for a lot of useful methods that you can
    override in your state descendants to capture various events. }
  TUIState = class(TUIControl)
  private
  type
    TDataImage = class
      Image: TCastleImage;
      GLImage: TGLImage;
      destructor Destroy; override;
    end;
    TDataImageList = specialize TFPGObjectList<TDataImage>;
    TUIStateList = specialize TFPGObjectList<TUIState>;
  var
    FDataImages: TDataImageList;
    FStartContainer: TUIContainer;
    procedure InternalStart;
    procedure InternalFinish;

    class var FStateStack: TUIStateList;
    class function GetCurrent: TUIState; static;
    class procedure SetCurrent(const Value: TUIState); static;
    class function GetStateStack(const Index: Integer): TUIState; static;
  protected
    { Adds image to the list of automatically loaded images for this state.
      Path is automatically wrapped in ApplicationData(Path) to get URL.
      The basic image (TCastleImage) is loaded immediately,
      and always available, under DataImage(Index).
      The OpenGL image resource (TGLImage) is loaded when GL context
      is active, available under DataGLImage(Index).
      Where Index is the return value of this method. }
    function AddDataImage(const Path: string): Integer;
    function DataImage(const Index: Integer): TCastleImage;
    function DataGLImage(const Index: Integer): TGLImage;
    { Container on which state works. By default, this is Application.MainWindow.
      When the state is current, then @link(Container) property (from
      ancestor, see TUIControl.Container) is equal to this. }
    function StateContainer: TUIContainer; virtual;
  public
    { Current state. In case multiple states are active (only possible
      if you used @link(Push) method), this is the bottom state.
      Setting this resets whole state stack. }
    class property Current: TUIState read GetCurrent write SetCurrent;

    { Pushing the state adds it above the @link(Current) state.

      The current state is conceptually at the bottom of state stack, always.
      When it is nil, then pushing new state sets the @link(Current) state.
      Otherwise @link(Current) state is left as-it-is, new state is added on top. }
    class procedure Push(const NewState: TUIState);

    class function StateStackCount: Integer;
    class property StateStack [const Index: Integer]: TUIState read GetStateStack;

    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    { State becomes current.
      This is called right before adding the state to the
      @code(StateContainer.Controls) list, so the state methods
      GLContextOpen and ContainerResize will be called next (as for all
      normal TUIControl). }
    procedure Start; virtual;

    { State is no longer current.
      This is called after removing the state from the
      @code(StateContainer.Controls) list.

      This is always called to finalize the started state.
      When the current state is destroyed, it's @link(Finish) is called
      too. So you can use this method to reliably finalize whatever
      you initialized in @link(Start). }
    procedure Finish; virtual;

    function PositionInside(const Position: TVector2Single): boolean; override;
    procedure GLContextOpen; override;
    procedure GLContextClose; override;
  end;

implementation

uses SysUtils,
  CastleWindow, CastleWarnings, CastleFilesUtils, CastleUtils;

{ TUIState.TDataImage ---------------------------------------------------------- }

destructor TUIState.TDataImage.Destroy;
begin
  FreeAndNil(Image);
  FreeAndNil(GLImage);
  inherited;
end;

{ TUIState --------------------------------------------------------------------- }

class function TUIState.GetCurrent: TUIState;
begin
  if (FStateStack = nil) or
     (FStateStack.Count = 0) then
    Result := nil else
    Result := FStateStack[0];
end;

class procedure TUIState.SetCurrent(const Value: TUIState);
var
  TopState: TUIState;
begin
  { exit early if there's nothing to do }
  if (StateStackCount = 0) and (Value = nil) then
    Exit;
  if (StateStackCount = 1) and (FStateStack[0] = Value) then
    Exit;

  { Remove and finish topmost state.
    The loop is written to work even when some state Finish method
    changes states. }
  while StateStackCount <> 0 do
  begin
    TopState := FStateStack.Last;
    TopState.InternalFinish;
    if TopState = FStateStack.Last then
      FStateStack.Delete(FStateStack.Count - 1) else
      OnWarning(wtMinor, 'State', 'Topmost state is no longer topmost after its Finish method. Do not change state stack from state Finish methods.');
  end;
  { deallocate empty FStateStack }
  if Value = nil then
    FreeAndNil(FStateStack);

  Push(Value);
end;

class procedure TUIState.Push(const NewState: TUIState);
begin
  if NewState <> nil then
  begin
    { create FStateStack on demand now }
    if FStateStack = nil then
      FStateStack := TUIStateList.Create(false);
    FStateStack.Add(NewState);
    NewState.InternalStart;
  end;
end;

class function TUIState.StateStackCount: Integer;
begin
  if FStateStack = nil then
    Result := 0 else
    Result := FStateStack.Count;
end;

class function TUIState.GetStateStack(const Index: Integer): TUIState;
begin
  if FStateStack = nil then
    raise EInternalError.CreateFmt('TUIState.GetStateStack: state stack is empty, cannot get state index %d',
      [Index]);
  Result := FStateStack[Index];
end;

procedure TUIState.InternalStart;
var
  ControlsCount, PositionInControls: Integer;
  NewControls: TUIControlList;
begin
  NewControls := StateContainer.Controls;
  ControlsCount := NewControls.Count;
  Start;

  { actually insert to NewControls, this will also call GLContextOpen
    and ContainerResize.
    However, check first that we're still the current state,
    to safeguard from the fact that Start changed state
    (like the loading state, that changes to play state immediately in start). }
  if FStateStack.IndexOf(Self) <> -1 then
  begin
    PositionInControls := NewControls.Count - ControlsCount;
    if PositionInControls < 0 then
    begin
      OnWarning(wtMinor, 'State', 'TUIState.Start removed some controls from container');
      PositionInControls := 0;
    end;
    NewControls.Insert(PositionInControls, Self);
  end;
end;

procedure TUIState.InternalFinish;
begin
  StateContainer.Controls.Remove(Self);
  Finish;
end;

function TUIState.StateContainer: TUIContainer;
begin
  if FStartContainer <> nil then
    { between Start and Finish, be sure to return the same thing
      from StateContainer method. Also makes it working when Application
      is nil when destroying state from CastleWindow finalization. }
    Result := FStartContainer else
    Result := Application.MainWindow.Container;
end;

constructor TUIState.Create(AOwner: TComponent);
begin
  inherited;
  FDataImages := TDataImageList.Create;
end;

destructor TUIState.Destroy;
begin
  { finish yourself and remove from FStateStack, if present there }
  if (FStateStack <> nil) and
     (FStateStack.IndexOf(Self) <> -1) then
  begin
    InternalFinish;
    FStateStack.Remove(Self);
    { deallocate empty FStateStack. Doing this here allows to deallocate
      FStateStack only once all states finished gracefully. }
    if FStateStack.Count = 0 then
      FreeAndNil(FStateStack);
  end;

  FreeAndNil(FDataImages);
  inherited;
end;

procedure TUIState.Start;
begin
  FStartContainer := StateContainer;
end;

procedure TUIState.Finish;
begin
  FStartContainer := nil;
end;

function TUIState.AddDataImage(const Path: string): Integer;
var
  DI: TDataImage;
begin
  DI := TDataImage.Create;
  DI.Image := LoadImage(ApplicationData(Path), []);
  if GLInitialized then
    DI.GLImage := TGLImage.Create(DI.Image, true);
  Result := FDataImages.Add(DI);
end;

function TUIState.DataImage(const Index: Integer): TCastleImage;
begin
  Result := FDataImages[Index].Image;
end;

function TUIState.DataGLImage(const Index: Integer): TGLImage;
begin
  Result := FDataImages[Index].GLImage;
end;

function TUIState.PositionInside(const Position: TVector2Single): boolean;
begin
  Result := true;
end;

procedure TUIState.GLContextOpen;
var
  I: Integer;
  DI: TDataImage;
begin
  inherited;
  for I := 0 to FDataImages.Count - 1 do
  begin
    DI := FDataImages[I];
    if DI.GLImage = nil then
      DI.GLImage := TGLImage.Create(DI.Image, true);
  end;
end;

procedure TUIState.GLContextClose;
var
  I: Integer;
begin
  if FDataImages <> nil then
    for I := 0 to FDataImages.Count - 1 do
      FreeAndNil(FDataImages[I].GLImage);
  inherited;
end;

end.