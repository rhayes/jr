class MpxApi
  include HTTParty
  #base_uri "http://bracket.dev/api/v1"

  debug_output


  def initialize(options={})
    authorization_token = '6Rze4A3jsqPyezFDCmIZeLhUc2UoORco'

    @headers = {"Content-Type" => "application/json", "Authorization" => "Token #{authorization_token}"}

    self.class.base_uri "http://mpx-console.test/api/v1"
  end

  #index
  def resellers_list(params={})
    response = self.class.get("/resellers", :headers => @headers, :query => params)
    if response.code == 200
      return JSON.parse response.body
    else
      return false
    end
  end
end
