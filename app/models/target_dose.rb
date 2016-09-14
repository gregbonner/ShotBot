class TargetDose
  include ActiveModel::Model
  include AgeCalc
  include TargetDoseEvaluation

  attr_accessor :patient, :antigen_series_dose
  attr_reader :eligible, :satisfied, :status_hash, :antigen_administered_record

  def initialize(patient:, antigen_series_dose:)
    @antigen_series_dose         = antigen_series_dose
    @patient                     = patient
    @eligible                    = nil
    @status_hash                 = nil
    @antigen_administered_record = nil
  end

  [
    'dose_number', 'absolute_min_age', 'min_age', 'earliest_recommended_age',
    'latest_recommended_age', 'max_age', 'intervals', 'required_gender',
    'recurring_dose', 'dose_vaccines', 'preferable_vaccines',
    'allowable_vaccines'
  ].each do |action|
    define_method(action) do
      return nil if antigen_series_dose.nil?
      antigen_series_dose.send(action)
    end
  end

  def evaluate_antigen_administered_record(antigen_administered_record)
    if !@status_hash.nil? && @status_hash[:evaluation_status] == 'valid'
      raise Error('The TargetDose has already evaluated to True')
    end
    @antigen_administered_record = antigen_administered_record
    @status_hash = evaluate_satisfy_target_dose(antigen_administered_record)
    @satisfied   = @status_hash[:target_dose_status] == 'satisfied'
    @satisfied
  end

  def has_conditional_skip?
    !self.antigen_series_dose.conditional_skip.nil?
  end

  def evaluate_interval(first_administered_record, second_administered_record)
    all_intervals = self.intervals
    interval = all_intervals.first
    # interval.

  end

  def evaluate_preferable_vaccine(antigen_administered_record)
    preferable_vaccine_status_hash = {}
    preferable_cvx = self.preferable_vaccines.map(&:cvx_code)
    if !preferable_cvx.include?(antigen_administered_record.cvx_code)
      preferable_vaccine_status_hash[:preferable] = 'No'
      preferable_vaccine_status_hash[:reason] = 'not_included'
    end
  end

  def evaluate_satisfy_target_dose(antigen_administered_record,
                                   previous_antigen_administered_record=nil)
    previous_status_hash  = nil
    date_of_previous_dose = nil
    unless previous_antigen_administered_record.nil?
      previous_status_hash =
        previous_antigen_administered_record.target_dose.status_hash
      date_of_previous_dose =
        previous_antigen_administered_record.date_administered
    end
    evaluate_target_dose_satisfied(
      conditional_skip: @antigen_series_dose.conditional_skip,
      antigen_series_dose: @antigen_series_dose,
      preferable_intervals: @antigen_series_dose.preferable_intervals,
      allowable_intervals: @antigen_series_dose.allowable_intervals,
      antigen_series_dose_vaccines: @antigen_series_dose.dose_vaccines,
      patient_dob: @patient.dob,
      patient_gender: @patient.gender,
      patient_vaccine_doses: @patient.vaccine_doses,
      dose_cvx: antigen_administered_record.cvx_code,
      date_of_dose: antigen_administered_record.date_administered,
      dose_trade_name: antigen_administered_record.trade_name,
      dose_volume: antigen_administered_record.dosage,
      date_of_previous_dose: date_of_previous_dose,
      previous_dose_status_hash: previous_status_hash
    )
  end

  # def evaluate_vs_antigen_administered_record(antigen_administered_record)
  #   age_eligible?(@patient.dob)
  #   if !self.eligible
  #     return
  #   end
  # end
end



# Date Administered
# Patient Immunization History Administered - Dose Count
#     # when 'Age'
#   result = validate_date_equal_or_after(condition_attrs['begin_age_date'],
#                                         date_of_dose)
#   if condition_attrs['end_age_date']
#   end
#   evaluate begin_age
#   evaluate end_age? => need to look into this morer
# when 'Interval'
# when 'Vaccine Count by Age'
# when 'Vaccine Count by Date'

# A patient's reference dose date must be calculated as the
# date administered of the most immediate previous vaccine
# dose administered which has evaluation status “Valid” or “Not
# Valid” if from immediate previous dose administered is “Y”.

