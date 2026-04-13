# Lexicon fixture modules for Atex.LexiconTest.
#
# Defined in test/support so they are compiled before tests run, ensuring
# Code.ensure_loaded? and function_exported? return correct results even when
# Atex.LexiconTest runs with async: true.

# Standalone record used as the target of cross-NSID ref/union tests.
# NSID "lexicon.test.profileView" -> Lexicon.Test.ProfileView
defmodule Lexicon.Test.ProfileView do
  @moduledoc false
  use Atex.Lexicon

  deflexicon(%{
    "lexicon" => 1,
    "id" => "lexicon.test.profileView",
    "defs" => %{
      "main" => %{
        "type" => "object",
        "required" => ["did"],
        "properties" => %{
          "did" => %{"type" => "string"}
        }
      }
    }
  })
end

# Standalone record used as the second member of cross-NSID union tests.
# NSID "lexicon.test.errorView" -> Lexicon.Test.ErrorView
defmodule Lexicon.Test.ErrorView do
  @moduledoc false
  use Atex.Lexicon

  deflexicon(%{
    "lexicon" => 1,
    "id" => "lexicon.test.errorView",
    "defs" => %{
      "main" => %{
        "type" => "object",
        "required" => ["error"],
        "properties" => %{
          "error" => %{"type" => "string"}
        }
      }
    }
  })
end

# Procedure whose input.schema is a local `ref` to a sibling def.
# NSID "lexicon.test.createPost" -> Lexicon.Test.CreatePost
defmodule Lexicon.Test.CreatePost do
  @moduledoc false
  use Atex.Lexicon

  deflexicon(%{
    "lexicon" => 1,
    "id" => "lexicon.test.createPost",
    "defs" => %{
      "main" => %{
        "type" => "procedure",
        "input" => %{
          "encoding" => "application/json",
          "schema" => %{"type" => "ref", "ref" => "#postInput"}
        },
        "output" => %{
          "encoding" => "application/json",
          "schema" => %{
            "type" => "object",
            "required" => ["uri"],
            "properties" => %{"uri" => %{"type" => "string"}}
          }
        }
      },
      "postInput" => %{
        "type" => "object",
        "required" => ["text"],
        "properties" => %{
          "text" => %{"type" => "string"}
        }
      }
    }
  })
end

# Query whose output.schema is a local `ref` to a sibling def.
# NSID "lexicon.test.getPost" -> Lexicon.Test.GetPost
defmodule Lexicon.Test.GetPost do
  @moduledoc false
  use Atex.Lexicon

  deflexicon(%{
    "lexicon" => 1,
    "id" => "lexicon.test.getPost",
    "defs" => %{
      "main" => %{
        "type" => "query",
        "output" => %{
          "encoding" => "application/json",
          "schema" => %{"type" => "ref", "ref" => "#postView"}
        }
      },
      "postView" => %{
        "type" => "object",
        "required" => ["uri"],
        "properties" => %{
          "uri" => %{"type" => "string"}
        }
      }
    }
  })
end

# Procedure whose input.schema is a cross-NSID `ref` targeting a `main` def.
# NSID "lexicon.test.createProfile" -> Lexicon.Test.CreateProfile
defmodule Lexicon.Test.CreateProfile do
  @moduledoc false
  use Atex.Lexicon

  deflexicon(%{
    "lexicon" => 1,
    "id" => "lexicon.test.createProfile",
    "defs" => %{
      "main" => %{
        "type" => "procedure",
        "input" => %{
          "encoding" => "application/json",
          "schema" => %{"type" => "ref", "ref" => "lexicon.test.profileView"}
        }
      }
    }
  })
end

# Procedure whose input.schema is a `union` of two local refs.
# NSID "lexicon.test.createUnion" -> Lexicon.Test.CreateUnion
defmodule Lexicon.Test.CreateUnion do
  @moduledoc false
  use Atex.Lexicon

  deflexicon(%{
    "lexicon" => 1,
    "id" => "lexicon.test.createUnion",
    "defs" => %{
      "main" => %{
        "type" => "procedure",
        "input" => %{
          "encoding" => "application/json",
          "schema" => %{
            "type" => "union",
            "refs" => ["#postInput", "#errorInput"]
          }
        }
      },
      "postInput" => %{
        "type" => "object",
        "required" => ["text"],
        "properties" => %{
          "text" => %{"type" => "string"}
        }
      },
      "errorInput" => %{
        "type" => "object",
        "required" => ["error"],
        "properties" => %{
          "error" => %{"type" => "string"}
        }
      }
    }
  })
end

# Procedure with a raw (non-JSON) input - encoding only, no schema.
# NSID "lexicon.test.uploadBlob" -> Lexicon.Test.UploadBlob
defmodule Lexicon.Test.UploadBlob do
  @moduledoc false
  use Atex.Lexicon

  deflexicon(%{
    "lexicon" => 1,
    "id" => "lexicon.test.uploadBlob",
    "defs" => %{
      "main" => %{
        "type" => "procedure",
        "input" => %{
          "encoding" => "image/jpeg"
        }
      }
    }
  })
end

# Procedure with a wildcard raw input encoding.
# NSID "lexicon.test.uploadAny" -> Lexicon.Test.UploadAny
defmodule Lexicon.Test.UploadAny do
  @moduledoc false
  use Atex.Lexicon

  deflexicon(%{
    "lexicon" => 1,
    "id" => "lexicon.test.uploadAny",
    "defs" => %{
      "main" => %{
        "type" => "procedure",
        "input" => %{
          "encoding" => "*/*"
        }
      }
    }
  })
end

# Query whose output.schema is a `union` of two cross-NSID refs.
# NSID "lexicon.test.getUnion" -> Lexicon.Test.GetUnion
defmodule Lexicon.Test.GetUnion do
  @moduledoc false
  use Atex.Lexicon

  deflexicon(%{
    "lexicon" => 1,
    "id" => "lexicon.test.getUnion",
    "defs" => %{
      "main" => %{
        "type" => "query",
        "output" => %{
          "encoding" => "application/json",
          "schema" => %{
            "type" => "union",
            "refs" => [
              "lexicon.test.profileView",
              "lexicon.test.errorView"
            ]
          }
        }
      }
    }
  })
end

# Query with defined errors.
# NSID "lexicon.test.doThing" -> Lexicon.Test.DoThing
defmodule Lexicon.Test.DoThing do
  @moduledoc false
  use Atex.Lexicon

  deflexicon(%{
    "lexicon" => 1,
    "id" => "lexicon.test.doThing",
    "defs" => %{
      "main" => %{
        "type" => "query",
        "parameters" => %{
          "type" => "params",
          "required" => ["arg"],
          "properties" => %{
            "arg" => %{"type" => "string"}
          }
        },
        "errors" => [
          %{"name" => "SomethingBroke", "description" => "Something went wrong"},
          %{"name" => "DoesNotCompute", "description" => "Invalid input provided"}
        ]
      }
    }
  })
end

# Procedure with defined errors.
# NSID "lexicon.test.doOtherThing" -> Lexicon.Test.DoOtherThing
defmodule Lexicon.Test.DoOtherThing do
  @moduledoc false
  use Atex.Lexicon

  deflexicon(%{
    "lexicon" => 1,
    "id" => "lexicon.test.doOtherThing",
    "defs" => %{
      "main" => %{
        "type" => "procedure",
        "input" => %{
          "encoding" => "application/json",
          "schema" => %{
            "type" => "object",
            "required" => ["data"],
            "properties" => %{
              "data" => %{"type" => "string"}
            }
          }
        },
        "errors" => [
          %{"name" => "ValidationFailed"}
        ]
      }
    }
  })
end
