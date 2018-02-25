unit UCTree;

interface
uses
  Tree,DataTypes,System.Math;
type
  //TODO
  //Choose best move to get childs from !!!!
  //not best UCT! This is only for exploration
  //get actually the most interesting move, which means the most critical winrate at his level
  TUCTNode = class;
  TUCTData = record
    X,Y : Integer;
    FBoard:PBoard;
    IsPassMove:Boolean;
    IsValid:Boolean;
    WinsWhite:Int64;
    WinsBlack:Int64;
    WinsWhiteAMAF:Int64;
    WinsBlackAMAF:Int64;
    UCTVal:Double;
    HasAllChilds:Boolean;
    ISUCTUpToDate:Boolean;
    WinsWhiteTotal:^Int64;
    WinsBlackTotal:^Int64;
    Depth:Integer;
    AssignedNode:TUCTNode;
  end;
  PUCTData = ^TUCTData;

  TUCTNode = class(TInterfacedObject,ICompareableData<PUCTData>)
  private
    FData:PUCTData;
    FParent:TTreeNode<PUCTData,TUCTNode>;
  public
    procedure FreeData;
    function CompareTo(AData:PUCTData):Integer;
    function GetData:PUCTData;
    procedure SetData(AData:PUCTData);
    function CalculateUCTValue:Double;
    property Parent:TTreeNode<PUCTData,TUCTNode> read FParent write FParent;
  end;

  TUCTree = class(TTree<PUCTData,TUCTNode>)
  private
    FWinsWhiteTotal:Int64;
    FWinsBlackTotal:Int64;
  public
      function DoesNodeHaveChild(ANode:TTreeNode<PUCTData,TUCTNode>;AX,AY:Integer):Boolean; //is there a good way to do this generic?
      procedure SetPointers(ANodeData:PUCTData);
      function GetBestMoveNode(ARootNode:TTreeNode<PUCTData,TUCTNode>;
                              const AOnlyFirstLevel:Boolean = True;
                              const InitialWR:Double = 0
                              ):TTreeNode<PUCTData,TUCTNode>;
      function UpdateAllAMAFSiblings(AAMAFNode:TTreeNode<PUCTData,TUCTNode>;ARootNode:TTreeNode<PUCTData,TUCTNode>;AIsWhiteWin:Boolean):Boolean;

                                                        // Maybe a "key" value in the treenode
    procedure UpdatePlayout(ANode:TTreeNode<PUCTData,TUCTNode>;AIsWinWhite:Boolean;AIsInitialNode:Boolean;const AIsAMAFUPdate:Boolean = false);
    constructor Create(ARootNodeData:TUCTNode);reintroduce;
  end;

implementation
 function TUCTree.UpdateAllAMAFSiblings(AAMAFNode:TTreeNode<PUCTData,TUCTNode>;ARootNode:TTreeNode<PUCTData,TUCTNode>;AIsWhiteWin:Boolean):Boolean;
var
  i:Integer;
begin
  if ARootNode <> AAMAFNode  then
  begin
    if (ARootNode.Content.GetData.FBoard.LastMoveCoordX =
       AAMAFNode.Content.GetData.FBoard.LastMoveCoordX) and
       (ARootNode.Content.GetData.FBoard.LastMoveCoordY =
       AAMAFNode.Content.GetData.FBoard.LastMoveCoordY) and
       (AAMAFNode.Content.GetData.FBoard.PlayerOnTurn =   //color preservation
        ARootNode.Content.GetData.FBoard.PlayerOnTurn) and
        (ARootNode.Depth<3) //if updated
    then
      UpdatePlayout(ARootNode,AIsWhiteWin,True,True);
  end;
  for i := 0 to ARootNode.ChildCount-1 do
    UpdateAllAMAFSiblings(AAMAFNode,ARootNode.Childs[i],AIsWhiteWin);
end;
constructor TUCTree.Create(ARootNodeData:TUCTNode);
begin
  inherited Create(ARootNodeData);
  FWinsWhiteTotal:=0;
  FWinsBlackTotal:=0;
end;
 function TUCTree.GetBestMoveNode(ARootNode:TTreeNode<PUCTData,TUCTNode>;const AOnlyFirstLevel:Boolean = True;const InitialWR:Double  = 0):TTreeNode<PUCTData,TUCTNode>;
 var
  CurWR,BestWR:Double;
  Ply:Int64;
  Wins:Int64;
  i:integer;
 begin
  BestWR:=0;
  if not AOnlyFirstLevel then
    BestWR:=InitialWR;
  Result:=ARootNode;
  for i := 0 to ARootNode.ChildCount-1 do
  begin
    Ply:=ARootNode.Childs[i].Content.GetData.WinsWhite+ARootNode.Childs[i].Content.GetData.WinsBlack;
    if Ply > 0 then
    begin
      if RootNode.Content.GetData.FBoard.PlayerOnTurn = 1 then
        Wins:=ARootNode.Childs[i].Content.GetData.WinsWhite
      else
        Wins:=ARootNode.Childs[i].Content.GetData.WinsBlack;
      CurWR:=Wins/Ply;//    ... /how to Choose best move for playing?=!=!=!=!=!=!�?!?=!==!
      if CurWR>BestWR then
    //  if Ply > ALPHA_AMAF_MINMOVES then
      begin
        BestWR:=CurWR;
        if not AOnlyFirstLevel then
          Result:=GetBestMoveNode(ARootNode.Childs[i],False,BestWR)
        else
          Result:=ARootNode.Childs[i]
      end;
    end;
  end;
 end;

procedure TUCTree.SetPointers(ANodeData:PUCTData);
begin
  ANodeData.WinsWhiteTotal:=@FWinsWhiteTotal;
  ANodeData.WinsBlackTotal:=@FWinsBlackTotal;
end;

procedure TUCTree.UpdatePlayout(ANode:TTreeNode<PUCTData,TUCTNode>;AIsWinWhite:Boolean;AIsInitialNode:Boolean;const AIsAMAFUPdate:Boolean = false);
var
  LPUCTData:PUCTData;
begin
  if ANode= nil then
    Exit;
  if ANode = RootNode then
  begin
   LPUCTData:=nil;
  end;
  LPUCTData:=ANode.Content.GetData;

  if AIsWinWhite then
  begin
    if AIsAMAFUPdate then
      Inc(LPUCTData.WinsWhiteAMAF)
    else
      inc(LPUCTData.WinsWhite);
  end
  else
  begin
    if AIsAMAFUPdate then
      Inc(LPUCTData.WinsBlackAMAF)
    else
      Inc(LPUCTData.WinsBlack);

  end;

if AIsInitialNode then
if not AIsAMAFUPdate then //don't count AMAF playouts as totals
begin
   if AIsWinWhite then
      Inc(LPUCTData.WinsWhiteTotal^)
   else
      Inc(LPUCTData.WinsBlackTotal^);
end;
  Anode.Content.GetData.ISUCTUpToDate:=False;
  ANode.Content.CalculateUCTValue;
  UpdatePlayout(ANode.Parent,AIsWinWhite,False,AIsAMAFUPdate);

end;

function TUCTree.DoesNodeHaveChild(ANode:TTreeNode<PUCTData,TUCTNode>;AX,AY:Integer):Boolean;
var
  i:Integer;
begin
  Result:=False;
  for i := 0 to ANode.ChildCount-1 do
  begin
    if
      (ANode.Childs[i].Content.FData.X = AX)
      AND
      (Anode.Childs[i].Content.FData.Y = AY)
    then
      Exit(True);
  end;
end;

procedure TUCTNode.SetData(AData:PUCTData);
begin
  FData:=AData;
end;

function TUCTNode.CalculateUCTValue:Double;
var
  LPly:Double;
  LPlyTotal:Double;
  LWins:Double;
  LWinsAMAF:Double;
  LPlyAMAF:Double;
  LPlyAMAFTotal:Double;
  LPlyAMAFUCT:Double;
  LAlphaAMAFFactor:Double;
begin
  //if not FData.ISUCTUpToDate then
  begin

    LPly:=FData.WinsWhite+FData.WinsBlack;
    LPlyAMAF:=FData.WinsWhiteAMAF+FData.WinsBlackAMAF;
    if Assigned(Parent) then
    begin
      LPlyTotal:=Parent.Content.GetData^.WinsWhite+Parent.Content.GetData^.WinsBlack;
      LPlyAMAFTotal:=Parent.Content.GetData^.WinsWhiteAMAF+Parent.Content.GetData^.WinsBlackAMAF;
    end
    else
    begin
      LPlyTotal:=FData.WinsWhite+FData.WinsBlack;
      LPlyAMAFTotal:=FData.WinsWhiteAMAF+FData.WinsBlackAMAF;
    end;

    if (LPly>0) and (LPlyTotal>0) then
    begin
      if FData.FBoard.PlayerOnTurn = 2 then
      begin
        LWins:=FData.WinsWhite;
        LWinsAMAF:=FData.WinsWhiteAMAF;
      end
      else
      begin
        LWins:=FData.WinsBlack;
        LWinsAMAF:=FData.WinsBlackAMAF;
      end;

      FData.UCTVal:= (( LWins/LPly)
         +EXPLORATION_FACTOR_START*
         sqrt(Ln(LPlyTotal)/LPly));///(FData.Depth+1);
      if (LPlyAMAF>0) and (LPlyAMAFTotal>0) then
      begin
        LPlyAMAFUCT:= ((LWinsAMAF/LPlyAMAF)
          +EXPLORATION_FACTOR_START*
          Sqrt(Ln(LPlyAMAFTotal)/LPlyAMAF));///(FData.Depth+1);
      end else
        LPlyAMAFUCT:=0;
      LAlphaAMAFFactor:=(ALPHA_AMAF_MINMOVES - LPly)/ALPHA_AMAF_MINMOVES;

      if LAlphaAMAFFactor<0 then
        LAlphaAMAFFactor:=0;
      if LPlyAMAFUCT > 0 then //if we don't have AMAF data, don't tamper with original playout values!
      begin
        FData.UCTVal:=FData.UCTVal*(1-LAlphaAMAFFactor) +
                      LAlphaAMAFFactor * LPlyAMAFUCT;
      end;
    end else
      FData.UCTVal:=1000;

    FData.ISUCTUpToDate:=True;
  end;
  Result:=FData.UCTVal;
end;

procedure TUCTNode.FreeData;
begin
  Dispose(FData.FBoard);
  Dispose(FData);
end;

function TUCTNode.CompareTo(AData:PUCTData):Integer;
begin
  Result:= IfThen((CalculateUCTValue-AData.AssignedNode.CalculateUCTValue)<0,-1,1);
end;

function TUCTNode.GetData:PUCTData;
begin
  Result:=FData;
end;
end.
