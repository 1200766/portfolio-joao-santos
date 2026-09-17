import { ComponentFixture, TestBed } from '@angular/core/testing';

import { MedicosListaComponent } from './medicos-lista.component';

describe('MedicosListaComponent', () => {
  let component: MedicosListaComponent;
  let fixture: ComponentFixture<MedicosListaComponent>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      declarations: [ MedicosListaComponent ]
    })
    .compileComponents();

    fixture = TestBed.createComponent(MedicosListaComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });
});
