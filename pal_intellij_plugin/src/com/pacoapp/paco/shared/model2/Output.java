package com.pacoapp.paco.shared.model2;

import org.codehaus.jackson.annotate.JsonProperty;

import java.io.Serializable;

public class Output implements Serializable {

  @JsonProperty("answer")
  private String value;

  private String name;

  public Output(String name, String value) {
    this.value = value;
    this.name = name;
  }

  @JsonProperty("answer")
  public String getValue() {
    return value;
  }

  @JsonProperty("answer")
  public void setValue(String value) {
    this.value = value;
  }

  public String getName() {
    return name;
  }

  public void setName(String name) {
    this.name = name;
  }

}
