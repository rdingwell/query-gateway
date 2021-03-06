require 'query_utilities'
require 'sprockets'
require 'tilt'
class QueryExecutor
  
  include QueryUtilities
  
  PATIENTS_COLELCTION = "records"
  RESULTS_COLLECTION = "query_results"
  
  def initialize(map_js, reduce_js, job_id, filter={})
    @map_js = map_js
    @reduce_js = reduce_js
    @job_id = job_id
    @filter = filter
  
    
  end
  
  def execute
    db =  Mongoid.master
    
    # convert the filter hash to a mongo query style hash.  Currently we are passing in a mongo style query hash so this is a no-op
    filter = convert_filter_to_mongo_query filter
    results = db[PATIENTS_COLELCTION].map_reduce(build_map_function , @reduce_js, :query => @filter, raw: true, out: {inline: 1})
    result_document = {}
    result_document["_id"] = @job_id
    results['results'].each do |result|
      result_document[result['_id']] = result['value']
    end

    db[RESULTS_COLLECTION].save(result_document)
  end
  
  def self.patient_api_javascript
    Tilt::CoffeeScriptTemplate.default_bare=true 
    Rails.application.assets.find_asset("patient")
  end
  
  private
  def build_map_function
    "function() {
      this.hQuery || (this.hQuery = {});
      var hQuery = this.hQuery;
      #{QueryExecutor.patient_api_javascript}
      #{@map_js}
      var patient = new hQuery.Patient(this);
      map(patient);
    };"
    
  end
end
