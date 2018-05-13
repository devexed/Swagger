unit Dv.Rtti.Attributes;

interface

uses
  System.RTTI;

type

  IntAttribute = class(TCustomAttribute)
  private
    FValue: Integer;
  public
    constructor Create(AValue: Integer);
    property Value: Integer read FValue;
  end;

  MaxLengthAttribute = class(IntAttribute);
  MinLengthAttribute = class(IntAttribute);

  NameAttribute = class(TCustomAttribute)
  private
    FValue: string;
  public
    constructor Create(AValue: string);
    property Name: string read FValue;
  end;

  KeyAttribute = class(TCustomAttribute);

implementation

{ TLengthAttribute }

constructor IntAttribute.Create(AValue: Integer);
begin
  FValue := AValue;
end;

{ TTableNameAttribute }

constructor NameAttribute.Create(AValue: string);
begin
  FValue := AValue;
end;

end.
