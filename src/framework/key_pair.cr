module Ktistec
  abstract class KeyPair
    abstract def iri
    abstract def public_key
    abstract def private_key
  end
end
