module ConditionalSkipEvaluation
  include EvaluationBase

  # Does the Conditional Skip Series Group identify a Series Group with at
  # least one series with a status of “Complete”?
  #   I believe this means that if it completes one of the series in the group,
  #   then it is valid. If not, then it is not and should not be included - But is
  #   this true?

  def create_conditional_skip_set_condition_attributes(
    condition,
    previous_dose_date,
    dob
  )
    condition_attrs = {}
    condition_attrs[:assessment_date] = Date.today.to_date
    condition_attrs[:condition_id]    = condition.condition_id
    condition_attrs[:condition_type]  = condition.condition_type

    time_attributes = %w(begin_age end_age)
    condition_attrs = create_calculated_dates(time_attributes, condition,
                                              dob, condition_attrs)

    expected_interval_date = create_patient_age_date(condition.interval,
                                                     previous_dose_date)
    condition_attrs[:interval_date] = expected_interval_date

    ['start_date', 'end_date'].each do |attribute|
      condition_attribute = condition.read_attribute(attribute)
      if !condition_attribute.nil? && condition_attribute != ''
        condition_attrs[attribute.to_sym] = Date.strptime(condition_attribute,
                                                          "%Y%m%d")
      else
        condition_attrs[attribute.to_sym] = nil
      end
    end
    condition_attrs[:dose_count] = if condition.dose_count == '' ||
                                      condition.dose_count.nil?
                                        nil
                                   else
                                      condition.dose_count.to_i
                                   end
    condition_attrs[:dose_type]        = condition.dose_type
    condition_attrs[:dose_count_logic] = condition.dose_count_logic
    condition_attrs[:vaccine_types]    = if !condition.vaccine_types.nil?
                                           condition.vaccine_types.split(";")
                                         else
                                           []
                                         end
    condition_attrs
  end

  def match_vaccine_doses_with_cvx_codes(vaccine_doses_administered,
                                         vaccine_types_cvx_codes)
    # What if there are no 'vaccine_types'?
    return [] if vaccine_types_cvx_codes.nil?
    vaccine_doses_administered.find_all do |vaccine_dose|
      vaccine_types_cvx_codes.include?(vaccine_dose.cvx_code)
    end
  end

  def calculate_count_of_vaccine_doses(vaccine_doses_administered,
                                       vaccine_types,
                                       begin_age_date: nil,
                                       end_age_date: nil,
                                       start_date: nil,
                                       end_date: nil,
                                       dose_type: nil
                                       )
    # This method counts the number of doses that follows all of the following
    # rules:
    #   a. Vaccine Type is one of the supporting data defined conditional skip
    #      vaccine types.
    #   b. Date Administered is:
    #     - on or after the conditional skip begin age date and before the
    #       conditional skip end age date OR
    #     - on or after the conditional skip start date and before conditional
    #       skip end date
    #   c. Evaluation Status is:
    #     - "Valid" if the conditional skip dose type is "Valid" OR
    #     - of any status if the conditional skip dose type is "Total"
    if vaccine_types.is_a?(String)
      vaccine_types = vaccine_types.split(';').map(&:to_i)
    end
    matched_vaccines = match_vaccine_doses_with_cvx_codes(
      vaccine_doses_administered,
      vaccine_types
    )
    matched_vaccines.select! do |match_vaccine|
      if begin_age_date && match_vaccine.date_administered < begin_age_date
        next false
      end
      if end_age_date && match_vaccine.date_administered > end_age_date
        next false
      end
      if start_date && match_vaccine.date_administered < start_date
        next false
      end
      if end_date && match_vaccine.date_administered > end_date
        next false
      end
      true
    end

    matched_vaccines.count
  end

  def evaluate_vaccine_dose_count(conditional_logic,
                                  required_dose_count,
                                  actual_dose_count)
    case conditional_logic
    when 'greater than'
      actual_dose_count > required_dose_count
    when 'equals'
      actual_dose_count == required_dose_count
    when 'less than'
      actual_dose_count < required_dose_count
    end
  end

  def evaluate_conditional_skip_set_condition_attributes(condition_attrs,
                                                         date_of_dose)
    # TABLE 6-7 CONDITIONAL TYPE OF COMPLETED SERIES – IS THE CONDITION MET?
    # How to evaluate this component?
    evaluated_hash = {}
    %w(
      begin_age_date
      start_date
      end_age_date
      end_date
      interval_date
    ).each do |condition_attr|
      result = nil
      if !condition_attrs[condition_attr.to_sym].nil?
        if ['end_age_date', 'end_date'].include?(condition_attr)
          result = validate_date_equal_or_before(
                     condition_attrs[condition_attr.to_sym],
                     date_of_dose
                   )
        else
          result = validate_date_equal_or_after(
                     condition_attrs[condition_attr.to_sym],
                     date_of_dose
                   )
        end
      end
      name_array = condition_attr.split('_')
      result_attr = if name_array.length == 3
                      name_array[0..-2].join('_')
                    else
                      condition_attr
                    end
      evaluated_hash[result_attr.to_sym] = result
    end
    evaluated_hash
  end


end