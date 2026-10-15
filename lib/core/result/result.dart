/// Base class for expected, typed failures.
sealed class Failure {
  const Failure(this.message);
  final String message;
  @override
  String toString() => '$runtimeType: $message';
}

class ValidationFailure extends Failure {
  const ValidationFailure(super.message);
}

class ConflictFailure extends Failure {
  const ConflictFailure(super.message, {this.conflictingId});
  final String? conflictingId;
}

/// The action is allowed but the user must explicitly confirm it first.
class ConfirmationRequiredFailure extends Failure {
  const ConfirmationRequiredFailure(super.message);
}

class NotFoundFailure extends Failure {
  const NotFoundFailure(super.message);
}

class UnexpectedFailure extends Failure {
  const UnexpectedFailure(super.message);
}

sealed class Result<T> {
  const Result();
  const factory Result.ok(T value) = Ok<T>;
  const factory Result.err(Failure failure) = Err<T>;

  bool get isOk => this is Ok<T>;
  T? get valueOrNull => switch (this) { Ok<T>(:final value) => value, _ => null };
  Failure? get failureOrNull =>
      switch (this) { Err<T>(:final failure) => failure, _ => null };

  R when<R>({required R Function(T) ok, required R Function(Failure) err}) =>
      switch (this) {
        Ok<T>(:final value) => ok(value),
        Err<T>(:final failure) => err(failure),
      };
}

final class Ok<T> extends Result<T> {
  const Ok(this.value);
  final T value;
}

final class Err<T> extends Result<T> {
  const Err(this.failure);
  final Failure failure;
}
