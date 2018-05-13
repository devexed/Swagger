unit Dv.Types;

interface

uses
  System.SysUtils, System.Variants, System.Rtti;

type

  // Nullable taget delvis från https://bitbucket.org/sglienke/spring4d
  // Licens: http://www.apache.org/licenses/LICENSE-2.0
  // Delphi Spring4D. Tredjepartsverktyg av Stefan Glienke.
  // Han är en känd person i Delphivärlden och på StackOverflow.

  Nullable = record
  private
    const HasValue = 'True';
    type Null = interface end;
  end;

  /// <summary>
  ///   A nullable type can represent the normal range of values for its
  ///   underlying value type, plus an additional <c>Null</c> value.
  /// </summary>
  /// <typeparam name="T">
  ///   The underlying value type of the <see cref="Nullable&lt;T&gt;" />
  ///   generic type.
  /// </typeparam>
  Nullable<T> = record
  private
    FValue: T;
    fHasValue: string;
    function GetValue: T; inline;
    function GetHasValue: Boolean; inline;
  public
    /// <summary>
    ///   Initializes a new instance of the <see cref="Nullable&lt;T&gt;" />
    ///   structure to the specified value.
    /// </summary>
    constructor Create(const value: T); overload;
    /// <summary>
    ///   Initializes a new instance of the <see cref="Nullable&lt;T&gt;" />
    ///   structure to the specified value.
    /// </summary>
    constructor Create(const value: Variant); overload;
    /// <summary>
    ///   Retrieves the value of the current <see cref="Nullable&lt;T&gt;" />
    ///   object, or the object's default value.
    /// </summary>
    // function GetValueOrDefault: T; overload; Kanske implementerar denna senare.
    /// <summary>
    ///   Retrieves the value of the current <see cref="Nullable&lt;T&gt;" />
    ///   object, or the specified default value.
    /// </summary>
    /// <param name="defaultValue">
    ///   A value to return if the <see cref="HasValue" /> property is <c>False</c>
    ///    .
    /// </param>
    /// <returns>
    ///   The value of the <see cref="Value" /> property if the <see cref="HasValue" />
    ///    property is true; otherwise, the <paramref name="defaultValue" />
    ///   parameter.
    /// </returns>
    /// <remarks>
    ///   The <see cref="GetValueOrDefault" /> method returns a value even if
    ///   the <see cref="HasValue" /> property is false (unlike the <see cref="Value" />
    ///    property, which throws an exception).
    /// </remarks>
    function GetValueOrDefault(const defaultValue: T): T; overload;
    /// <summary>
    ///   Returns the stored value as variant.
    /// </summary>
    /// <exception cref="EInvalidCast">
    ///   The type of T cannot be cast to Variant
    /// </exception>
    function ToVariant: Variant;
    /// <summary>
    ///   Gets a value indicating whether the current <see cref="Nullable&lt;T&gt;" />
    ///    structure has a value.
    /// </summary>
    property HasValue: Boolean read GetHasValue;
    /// <summary>
    ///   Gets the value of the current <see cref="Nullable&lt;T&gt;" /> value.
    /// </summary>
    /// <exception cref="Spring|EInvalidOperationException">
    ///   Raised if the value is null.
    /// </exception>
    property Value: T read GetValue;

    /// <summary>
    ///   Gets the stored value. Returns <c>False</c> if it does not contain a
    ///   value.
    /// </summary>
    function TryGetValue(out value: T): Boolean; inline;

    class operator Implicit(const value: Nullable.Null): Nullable<T>;
    class operator Implicit(const value: T): Nullable<T>;

    class operator Explicit(const value: Variant): Nullable<T>;
  end;

function VarIsNullOrEmpty(const value: Variant): Boolean;

implementation

function VarIsNullOrEmpty(const value: Variant): Boolean;
begin
  Result := FindVarData(value).VType in [varEmpty, varNull];
end;

{ Nullable<T> }

constructor Nullable<T>.Create(const value: T);
begin
  FValue := value;
  fHasValue := Nullable.HasValue;
end;

constructor Nullable<T>.Create(const value: Variant);
var
  v: TValue;
begin
  if not VarIsNullOrEmpty(value) then
  begin
    v := TValue.FromVariant(value);
    FValue := v.AsType<T>;
    fHasValue := Nullable.HasValue;
  end
  else
  begin
    fHasValue := '';
    FValue := Default(T);
  end;
end;

class operator Nullable<T>.Explicit(const value: Variant): Nullable<T>;
var
  v: TValue;
begin
  if not VarIsNullOrEmpty(value) then
  begin
    v := TValue.FromVariant(value);
    Result.FValue := v.AsType<T>;
    Result.fHasValue := Nullable.HasValue;
  end
  else
    Result := Default(Nullable<T>);
end;

function Nullable<T>.GetHasValue: Boolean;
begin
  Result := fHasValue <> '';
end;

function Nullable<T>.GetValue: T;
begin
  if not HasValue then
    raise EInvalidOpException.Create('Nullable<T> does not have a value.') at ReturnAddress;
  Result := FValue;
end;

{ function Nullable<T>.GetValueOrDefault: T;
begin
  if HasValue then
    Result := fValue
  else
    Result := Default(T);
end; }

function Nullable<T>.GetValueOrDefault(const defaultValue: T): T;
begin
  if HasValue then
    Result := FValue
  else
    Result := defaultValue;
end;

class operator Nullable<T>.Implicit(const value: Nullable.Null): Nullable<T>;
begin
  Result.FValue := Default(T);
  Result.fHasValue := '';
end;

class operator Nullable<T>.Implicit(const value: T): Nullable<T>;
begin
  Result.FValue := value;
  Result.fHasValue := Nullable.HasValue;
end;

function Nullable<T>.ToVariant: Variant;
var
  v: TValue;
begin
  if HasValue then
  begin
    v := TValue.From<T>(FValue);
    if v.IsType<Boolean> then
      Result := v.AsBoolean
    else
      Result := v.AsVariant;
  end
  else
    Result := Null;
end;

function Nullable<T>.TryGetValue(out value: T): Boolean;
begin
  Result := fHasValue <> '';
  if Result then
    value := FValue;
end;

end.
